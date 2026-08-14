import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_config.dart';
import 'pocketbase/pocketbase_server_manager.dart';

enum UpdateStatus {
  upToDate,
  updateAvailable,
  error,
}

class AppRelease {
  final String version;
  final String tagName;
  final String title;
  final String body;
  final DateTime? publishedAt;
  final String htmlUrl;
  final String? assetDownloadUrl;
  final String? assetName;
  final int? assetSize;
  final bool isPrerelease;

  const AppRelease({
    required this.version,
    required this.tagName,
    required this.title,
    required this.body,
    this.publishedAt,
    required this.htmlUrl,
    this.assetDownloadUrl,
    this.assetName,
    this.assetSize,
    this.isPrerelease = false,
  });

  String get formattedPublishedDate {
    if (publishedAt == null) return '';
    final dt = publishedAt!;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final monthStr = months[dt.month - 1];
    return '$monthStr ${dt.day}, ${dt.year}';
  }

  String get formattedSize {
    if (assetSize == null || assetSize! <= 0) return '';
    final mb = assetSize! / (1024 * 1024);
    if (mb >= 1.0) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = assetSize! / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name']?.toString() ?? '';
    final rawVersion = tagName.replaceAll(RegExp(r'^[vV]'), '');

    // Parse assets to find the most suitable installer or bundle
    String? downloadUrl;
    String? assetName;
    int? assetSize;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      dynamic match;

      // 1. Look for .exe on Windows
      for (final a in assets) {
        if (a is Map &&
            a['name'] != null &&
            a['name'].toString().toLowerCase().endsWith('.exe')) {
          match = a;
          break;
        }
      }

      // 2. Look for .zip or other installer if .exe not found
      if (match == null) {
        for (final a in assets) {
          if (a is Map &&
              a['name'] != null &&
              (a['name'].toString().toLowerCase().endsWith('.zip') ||
                  a['name'].toString().toLowerCase().endsWith('.apk') ||
                  a['name'].toString().toLowerCase().endsWith('.msix'))) {
            match = a;
            break;
          }
        }
      }

      // 3. Fallback to first available asset
      match ??= assets.first;

      if (match != null && match is Map) {
        downloadUrl = match['browser_download_url']?.toString();
        assetName = match['name']?.toString();
        assetSize = match['size'] is int
            ? match['size'] as int
            : int.tryParse(match['size']?.toString() ?? '');
      }
    }

    final publishedAtStr = json['published_at']?.toString();
    DateTime? publishedAt;
    if (publishedAtStr != null && publishedAtStr.isNotEmpty) {
      publishedAt = DateTime.tryParse(publishedAtStr);
    }

    return AppRelease(
      version: rawVersion.isNotEmpty ? rawVersion : tagName,
      tagName: tagName,
      title: json['name']?.toString() ?? tagName,
      body: json['body']?.toString() ?? '',
      publishedAt: publishedAt,
      htmlUrl: json['html_url']?.toString() ??
          'https://github.com/${AppConfig.githubOwner}/${AppConfig.githubRepo}/releases',
      assetDownloadUrl: downloadUrl,
      assetName: assetName,
      assetSize: assetSize,
      isPrerelease: json['prerelease'] == true,
    );
  }
}

class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final String preRelease;
  final int build;
  final String raw;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = '',
    this.build = 0,
    required this.raw,
  });

  static AppVersion parse(String versionStr) {
    final clean = versionStr.trim().replaceAll(RegExp(r'^[vV]'), '');
    int build = 0;
    String pre = '';
    String mainPart = clean;

    if (mainPart.contains('+')) {
      final parts = mainPart.split('+');
      mainPart = parts[0];
      build = int.tryParse(parts[1]) ?? 0;
    }

    if (mainPart.contains('-')) {
      final parts = mainPart.split('-');
      mainPart = parts[0];
      pre = parts.sublist(1).join('-');
    }

    final nums = mainPart.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final major = nums.isNotEmpty ? nums[0] : 0;
    final minor = nums.length > 1 ? nums[1] : 0;
    final patch = nums.length > 2 ? nums[2] : 0;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: pre,
      build: build,
      raw: versionStr,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // Release > Pre-release (e.g. 1.0.0 > 1.0.0-beta.1)
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;
    if (preRelease.isNotEmpty && other.preRelease.isNotEmpty) {
      final cmp = preRelease.compareTo(other.preRelease);
      if (cmp != 0) return cmp;
    }

    if (build != other.build) return build.compareTo(other.build);
    return 0;
  }

  bool isGreaterThan(AppVersion other) => compareTo(other) > 0;
  bool isLessThan(AppVersion other) => compareTo(other) < 0;
  bool isEqualTo(AppVersion other) => compareTo(other) == 0;

  @override
  String toString() => raw;
}

class UpdateCheckResult {
  final UpdateStatus status;
  final AppRelease? release;
  final String currentVersion;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.release,
    required this.currentVersion,
    this.errorMessage,
  });

  bool get isUpdateAvailable => status == UpdateStatus.updateAvailable;
  bool get isUpToDate => status == UpdateStatus.upToDate;
  bool get hasError => status == UpdateStatus.error;
}

class UpdateDownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double fraction;
  final String statusText;
  final bool isCompleted;

  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.fraction,
    required this.statusText,
    this.isCompleted = false,
  });

  int get percentage => (fraction * 100).clamp(0, 100).toInt();

  String get formattedReceived {
    final mb = receivedBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedTotal {
    if (totalBytes <= 0) return '-- MB';
    final mb = totalBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateDownloadCancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class UpdateService {
  UpdateService._();

  static final http.Client _httpClient = http.Client();

  /// Checks GitHub releases API for latest release and compares with [AppConfig.currentVersion].
  static Future<UpdateCheckResult> checkForUpdates({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final currentVerStr = AppConfig.currentVersion;
    final currentVer = AppVersion.parse(currentVerStr);

    try {
      final uri = Uri.parse(AppConfig.githubLatestReleaseUrl);
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'ShopFlow-POS-Desktop',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final release = AppRelease.fromJson(data);
        final remoteVer = AppVersion.parse(release.version);

        if (remoteVer.isGreaterThan(currentVer)) {
          return UpdateCheckResult(
            status: UpdateStatus.updateAvailable,
            release: release,
            currentVersion: currentVerStr,
          );
        } else {
          return UpdateCheckResult(
            status: UpdateStatus.upToDate,
            release: release,
            currentVersion: currentVerStr,
          );
        }
      } else if (response.statusCode == 404) {
        // Fallback: try fetching the list of all releases in case /latest is not configured
        final releasesListUri = Uri.parse(AppConfig.githubReleasesUrl);
        final listResponse = await _httpClient
            .get(
              releasesListUri,
              headers: {
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'ShopFlow-POS-Desktop',
              },
            )
            .timeout(timeout);

        if (listResponse.statusCode == 200) {
          final listData = jsonDecode(utf8.decode(listResponse.bodyBytes))
              as List<dynamic>;
          if (listData.isNotEmpty) {
            final latestJson = listData.first as Map<String, dynamic>;
            final release = AppRelease.fromJson(latestJson);
            final remoteVer = AppVersion.parse(release.version);

            if (remoteVer.isGreaterThan(currentVer)) {
              return UpdateCheckResult(
                status: UpdateStatus.updateAvailable,
                release: release,
                currentVersion: currentVerStr,
              );
            }
          }
          return UpdateCheckResult(
            status: UpdateStatus.upToDate,
            currentVersion: currentVerStr,
          );
        }

        return UpdateCheckResult(
          status: UpdateStatus.upToDate,
          currentVersion: currentVerStr,
          errorMessage: 'No release found on update server.',
        );
      } else if (response.statusCode == 403) {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVerStr,
          errorMessage:
              'GitHub API rate limit exceeded. Please try again in a few moments.',
        );
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVerStr,
          errorMessage:
              'Server returned code ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVerStr,
        errorMessage:
            'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVerStr,
        errorMessage: 'Connection timed out while checking for updates.',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVerStr,
        errorMessage: 'Failed to check updates: $e',
      );
    }
  }

  /// Downloads the release asset and reports progress through a Stream.
  static Stream<UpdateDownloadProgress> downloadReleaseAsset({
    required AppRelease release,
    required File targetFile,
    UpdateDownloadCancelToken? cancelToken,
  }) async* {
    final downloadUrl = release.assetDownloadUrl ?? release.htmlUrl;

    if (downloadUrl.isEmpty) {
      throw Exception('No valid download URL found for this release.');
    }

    // Ensure parent directory exists
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    final request = http.Request('GET', Uri.parse(downloadUrl));
    request.headers.addAll({
      'User-Agent': 'ShopFlow-POS-Desktop',
      'Accept': 'application/octet-stream',
    });

    final client = http.Client();
    http.StreamedResponse response;
    try {
      response = await client.send(request);
    } catch (e) {
      client.close();
      throw Exception('Could not connect to download server: $e');
    }

    if (response.statusCode != 200) {
      client.close();
      throw Exception(
          'Download failed with server status ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? release.assetSize ?? 0;
    int receivedBytes = 0;

    final sink = targetFile.openWrite();

    try {
      yield UpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: totalBytes,
        fraction: 0.0,
        statusText: 'Starting download...',
      );

      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          client.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          yield UpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            fraction: totalBytes > 0 ? (receivedBytes / totalBytes) : 0,
            statusText: 'Download cancelled',
          );
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final fraction = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        yield UpdateDownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          fraction: fraction,
          statusText: 'Downloading update package...',
        );
      }

      await sink.flush();
      await sink.close();
      client.close();

      yield UpdateDownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes > 0 ? totalBytes : receivedBytes,
        fraction: 1.0,
        statusText: 'Download complete!',
        isCompleted: true,
      );
    } catch (e) {
      await sink.close();
      client.close();
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Launches the downloaded installer executable, updates silently in the background, and relaunches the app automatically.
  static Future<bool> relaunchAndInstall(File installerFile) async {
    if (!await installerFile.exists()) {
      return false;
    }

    try {
      if (!kIsWeb && Platform.isWindows) {
        // 1. Stop local PocketBase server process if active to avoid file lock
        try {
          await PocketBaseServerManager.stop();
        } catch (_) {}

        final installerPath = p.normalize(installerFile.absolute.path);
        final appExePath = p.normalize(Platform.resolvedExecutable);
        final appDir = p.normalize(File(appExePath).parent.path);
        final currentPid = pid;

        // 2. Generate a dedicated background PowerShell relauncher script in temp directory
        final tempDir = Directory.systemTemp;
        final psScriptFile = File(p.join(
          tempDir.path,
          'ShopFlow_Update',
          'shopflow_updater_${DateTime.now().millisecondsSinceEpoch}.ps1',
        ));

        if (!psScriptFile.parent.existsSync()) {
          psScriptFile.parent.createSync(recursive: true);
        }

        final scriptContent = '''# ShopFlow POS Automated Silent Background Updater & Self-Relauncher
\$ErrorActionPreference = 'SilentlyContinue'

\$installerPath = '$installerPath'
\$appExePath    = '$appExePath'
\$appDir        = '$appDir'
\$appPid        = $currentPid

# 1. Allow the calling application process time to shut down cleanly
Start-Sleep -Seconds 1
if (\$appPid -gt 0) {
    try {
        \$parentProc = Get-Process -Id \$appPid -ErrorAction SilentlyContinue
        if (\$parentProc) {
            \$parentProc.WaitForExit(3000)
        }
    } catch {}
}

# Force terminate any remaining pos_system or pocketbase processes to prevent locked file conflicts
Get-Process -Name "pos_system", "pocketbase" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# 2. Run Inno Setup installer with Administrator Elevation (RunAs) and WAIT for complete installation
\$installerArgs = '/VERYSILENT /SUPPRESSMSGBOXES /FORCECLOSEAPPLICATIONS /SP- /NORESTART'
try {
    Start-Process -FilePath \$installerPath -ArgumentList \$installerArgs -Verb RunAs -Wait
} catch {
    # Fallback if RunAs is denied or not supported
    Start-Process -FilePath \$installerPath -ArgumentList \$installerArgs -Wait
}

# 3. Actively monitor until no installer process with that name is running
\$installerBaseName = [System.IO.Path]::GetFileNameWithoutExtension(\$installerPath)
\$maxWaitSeconds = 90
while (\$maxWaitSeconds -gt 0 -and (Get-Process -Name \$installerBaseName -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 1
    \$maxWaitSeconds--
}

# Brief pause to ensure all files are closed and unlocked on disk
Start-Sleep -Seconds 1

# 4. Relaunch the upgraded application in its installed working directory under standard user session
if (Test-Path \$appExePath) {
    Start-Process -FilePath \$appExePath -WorkingDirectory \$appDir
} else {
    \$fallbackPath = "\$env:LOCALAPPDATA\\Programs\\ShopFlow POS\\pos_system.exe"
    if (Test-Path \$fallbackPath) {
        Start-Process -FilePath \$fallbackPath -WorkingDirectory (Split-Path \$fallbackPath)
    }
}

# 5. Clean up temporary files
Start-Sleep -Seconds 2
try {
    Remove-Item -LiteralPath \$installerPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath \$PSCommandPath -Force -ErrorAction SilentlyContinue
} catch {}
''';

        await psScriptFile.writeAsString(scriptContent);

        // 3. Launch PowerShell detached & hidden to execute the update script
        await Process.start(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-WindowStyle',
            'Hidden',
            '-File',
            psScriptFile.path,
          ],
          mode: ProcessStartMode.detached,
        );

        // 4. Terminate current Flutter application process cleanly
        exit(0);
      } else {
        // For other platforms, launch file or URL
        await launchUrl(
          Uri.file(installerFile.path),
          mode: LaunchMode.externalApplication,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Error launching installer: $e');
      return false;
    }
  }

  /// Opens the release webpage in default browser
  static Future<bool> openReleasePage(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening release URL: $e');
      return false;
    }
  }

  /// Gets a standard temp file path for the downloaded update installer.
  static File getTempInstallerFile({String? assetName, String? version}) {
    final fileName = assetName ?? 'ShopFlow_POS_Setup_v${version ?? "new"}.exe';
    final tempDir = Directory.systemTemp;
    final updateDir = Directory(p.join(tempDir.path, 'ShopFlow_Update'));
    if (!updateDir.existsSync()) {
      try {
        updateDir.createSync(recursive: true);
      } catch (_) {}
    }
    return File(p.join(updateDir.path, fileName));
  }
}
