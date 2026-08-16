import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../core/constants/pocketbase_config.dart';

/// Service responsible for managing and auto-starting the local PocketBase server process.
class PocketBaseServerManager {
  static Completer<bool>? _initCompleter;
  static Process? _spawnedProcess;
  static int? _spawnedPid;

  /// Ensures that PocketBase is running on desktop platforms if not already active.
  static Future<bool> startIfNeeded({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return true;
    }

    if (_initCompleter != null) {
      return await _initCompleter!.future;
    }

    final completer = Completer<bool>();
    _initCompleter = completer;

    try {
      final configUri = Uri.parse(PocketBaseConfig.baseUrl);
      final host = configUri.host.isEmpty ? '127.0.0.1' : configUri.host;
      final port = configUri.port == 0 ? 8090 : configUri.port;

      debugPrint(
          '[PocketBaseServerManager] Checking if PocketBase is active on http://$host:$port...');

      // 1. Check if PocketBase is already running and responding to HTTP health check
      final alreadyRunning = await isServerHealthy(host: host, port: port);
      if (alreadyRunning) {
        debugPrint(
            '[PocketBaseServerManager] PocketBase is already running and ready on http://$host:$port.');
        completer.complete(true);
        return true;
      }

      // 2. Find PocketBase executable
      final exePath = _findExecutable();
      if (exePath == null) {
        debugPrint(
            '[PocketBaseServerManager] ERROR: Could not locate pocketbase executable.');
        completer.complete(false);
        return false;
      }

      final absoluteExe = p.normalize(File(exePath).absolute.path);
      final exeDir = File(absoluteExe).parent.path;
      final dataDir = _getDataDirectory(exeDir);

      // Clean up stale SQLite shared-memory lock files left behind by force-killed
      // PocketBase processes during updates. SHM files are safe to delete when no
      // process holds the database open — they are recreated automatically on open.
      // This prevents the new PocketBase instance from failing to acquire DB locks.
      for (final dbName in ['data.db', 'auxiliary.db']) {
        final shmFile = File(p.join(dataDir, '$dbName-shm'));
        if (shmFile.existsSync()) {
          try {
            shmFile.deleteSync();
            debugPrint(
                '[PocketBaseServerManager] Removed stale lock file: ${shmFile.path}');
          } catch (e) {
            debugPrint(
                '[PocketBaseServerManager] Could not remove ${shmFile.path}: $e');
          }
        }
      }

      debugPrint(
          '[PocketBaseServerManager] Found executable: $absoluteExe');
      debugPrint(
          '[PocketBaseServerManager] Data directory: $dataDir');

      final processArgs = [
        'serve',
        '--http=$host:$port',
        '--dir=$dataDir',
      ];

      final hooksDir = p.join(exeDir, 'pb_hooks');
      if (Directory(hooksDir).existsSync()) {
        processArgs.add('--hooksDir=$hooksDir');
      }

      final migrationsDir = p.join(exeDir, 'pb_migrations');
      if (Directory(migrationsDir).existsSync()) {
        processArgs.add('--migrationsDir=$migrationsDir');
      }

      debugPrint(
          '[PocketBaseServerManager] Launching PocketBase with args: $processArgs');

      // 3. Launch PocketBase server process with hidden window & stdio capture
      final stdLogs = <String>[];
      final process = await Process.start(
        absoluteExe,
        processArgs,
        mode: ProcessStartMode.normal,
        workingDirectory: exeDir,
      );

      _spawnedProcess = process;
      _spawnedPid = process.pid;

      process.stdout.transform(utf8.decoder).listen((data) {
        final trimmed = data.trim();
        if (trimmed.isNotEmpty) {
          stdLogs.add('[PB STDOUT] $trimmed');
          debugPrint('[PocketBaseServerManager STDOUT] $trimmed');
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        final trimmed = data.trim();
        if (trimmed.isNotEmpty) {
          stdLogs.add('[PB STDERR] $trimmed');
          debugPrint('[PocketBaseServerManager STDERR] $trimmed');
        }
      });

      debugPrint(
          '[PocketBaseServerManager] PocketBase process started (PID: ${process.pid}). Waiting for server health endpoint...');

      // 4. Wait for server HTTP health readiness check
      final ready = await _waitForServerReady(
        host: host,
        port: port,
        process: process,
        timeout: timeout,
      );

      if (ready) {
        debugPrint(
            '[PocketBaseServerManager] PocketBase server successfully ready on http://$host:$port.');
        completer.complete(true);
        return true;
      } else {
        debugPrint(
            '[PocketBaseServerManager] ERROR: Server startup failed or timed out after ${timeout.inSeconds}s on $host:$port.');
        if (stdLogs.isNotEmpty) {
          debugPrint(
              '[PocketBaseServerManager] Diagnostic Logs:\n${stdLogs.join("\n")}');
        }
        await stop();
        completer.complete(false);
        return false;
      }
    } catch (e, stack) {
      debugPrint(
          '[PocketBaseServerManager] Exception during server startup: $e\n$stack');
      completer.complete(false);
      return false;
    } finally {
      _initCompleter = null;
    }
  }

  /// Checks if directory is writeable by attempting temporary file creation.
  static bool _isWriteableDir(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final testFile = File(p.join(
          dirPath, '.write_test_${DateTime.now().millisecondsSinceEpoch}'));
      testFile.writeAsStringSync('test');
      testFile.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Determines a consistent, writeable data directory for PocketBase (`pb_data`).
  static String _getDataDirectory(String exeDir) {
    // In dev mode (where source files like pubspec.yaml exist in cwd), use local pb_data
    final cwd = Directory.current.path;
    final devPubspec = File(p.join(cwd, 'pubspec.yaml'));
    final exePubspec = File(p.join(exeDir, 'pubspec.yaml'));

    if (devPubspec.existsSync() || exePubspec.existsSync()) {
      final devDataDir = p.join(cwd, 'pb_data');
      if (_isWriteableDir(cwd)) {
        return devDataDir;
      }
    }

    // Installed application mode: Always store data in user AppData directory to guarantee
    // consistency across administrator and standard user execution contexts.
    final defaultTemplateDataDir = p.join(exeDir, 'pb_data');

    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.systemTemp.path;
    final userAppDataDir = p.join(appData, 'ShopFlow POS', 'pb_data');

    if (!Directory(userAppDataDir).existsSync()) {
      try {
        Directory(userAppDataDir).createSync(recursive: true);
        if (Directory(defaultTemplateDataDir).existsSync()) {
          _copyDirectorySync(
              Directory(defaultTemplateDataDir), Directory(userAppDataDir));
          debugPrint(
              '[PocketBaseServerManager] Initialized AppData pb_data from bundled template: $userAppDataDir');
        }
      } catch (e) {
        debugPrint(
            '[PocketBaseServerManager] Warning initializing AppData data directory: $e');
      }
    }

    return userAppDataDir;
  }

  /// Recursively copies a directory.
  static void _copyDirectorySync(Directory source, Directory destination) {
    destination.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      if (entity is Directory) {
        final newDir = Directory(
            p.join(destination.absolute.path, p.basename(entity.path)));
        _copyDirectorySync(entity, newDir);
      } else if (entity is File) {
        entity.copySync(
            p.join(destination.absolute.path, p.basename(entity.path)));
      }
    }
  }

  /// Checks if PocketBase is listening and responding to HTTP health checks on [host]:[port].
  static Future<bool> isServerHealthy({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final hostsToTry = <String>{'127.0.0.1'};
    if (host.isNotEmpty && host != '127.0.0.1') {
      hostsToTry.add(host);
    }

    for (final h in hostsToTry) {
      try {
        final uri = Uri.parse('http://$h:$port/api/health');
        final response = await http.get(uri).timeout(timeout);
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Backward compatible helper checking if server is active.
  static Future<bool> isServerRunning({
    required String host,
    required int port,
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    return isServerHealthy(host: host, port: port, timeout: timeout);
  }

  /// Periodically polls HTTP health endpoint until PocketBase responds or timeout occurs.
  /// Also monitors whether the process exits prematurely during startup.
  static Future<bool> _waitForServerReady({
    required String host,
    required int port,
    Process? process,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      // 1. Abort early if the process died/exited
      if (process != null) {
        bool hasExited = false;
        try {
          await process.exitCode.timeout(const Duration(milliseconds: 10));
          hasExited = true;
        } catch (_) {}

        if (hasExited) {
          debugPrint(
              '[PocketBaseServerManager] ERROR: PocketBase process exited prematurely.');
          return false;
        }
      }

      // 2. Poll health check
      if (await isServerHealthy(host: host, port: port)) {
        return true;
      }

      await Future.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }

  /// Dynamically locates pocketbase executable file path across Debug, Release, and Installed app environments.
  static String? _findExecutable() {
    final isWin = Platform.isWindows;
    final exeName = isWin ? 'pocketbase.exe' : 'pocketbase';

    String? checkCandidate(String path) {
      final file = File(path);
      if (file.existsSync()) {
        return p.normalize(file.absolute.path);
      }
      return null;
    }

    // Priority 1: Next to application binary (Release build / Installed app)
    try {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final appMatch = checkCandidate(p.join(appDir, exeName));
      if (appMatch != null) return appMatch;

      var parent = Directory(appDir);
      for (int i = 0; i < 6; i++) {
        parent = parent.parent;
        final match = checkCandidate(p.join(parent.path, exeName));
        if (match != null) return match;
      }
    } catch (_) {}

    // Priority 2: Working directory (Development mode / flutter run)
    final cwd = Directory.current.path;
    final cwdMatch = checkCandidate(p.join(cwd, exeName));
    if (cwdMatch != null) return cwdMatch;

    final assetsMatch = checkCandidate(p.join(cwd, 'assets', exeName));
    if (assetsMatch != null) return assetsMatch;

    var parentCwd = Directory(cwd);
    for (int i = 0; i < 6; i++) {
      parentCwd = parentCwd.parent;
      final match = checkCandidate(p.join(parentCwd.path, exeName));
      if (match != null) return match;
    }

    return exeName;
  }

  /// Stop server process if spawned by this application instance.
  static Future<void> stop() async {
    final process = _spawnedProcess;
    final pid = _spawnedPid;
    _spawnedProcess = null;
    _spawnedPid = null;

    if (process != null || pid != null) {
      debugPrint(
          '[PocketBaseServerManager] Stopping spawned PocketBase server (PID: $pid)...');
      try {
        process?.kill(ProcessSignal.sigkill);
      } catch (e) {
        debugPrint('[PocketBaseServerManager] Error killing process handle: $e');
      }

      if (pid != null) {
        try {
          Process.killPid(pid);
        } catch (_) {}
      }

      debugPrint('[PocketBaseServerManager] PocketBase process stopped.');
    }
  }
}

