import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_config.dart';
import '../widgets/update_dialog.dart';
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
  final String? assetDigest;
  final bool isPrerelease;
  final bool isDraft;

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
    this.assetDigest,
    this.isPrerelease = false,
    this.isDraft = false,
  });

  static String expectedInstallerFileName(String version) {
    final cleanVer = version.trim().replaceAll(RegExp(r'^[vV]'), '');
    return 'ShopFlow_POS_Setup_v$cleanVer.exe';
  }

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

    // Parse assets to find the exact version-matching Windows installer .exe
    String? downloadUrl;
    String? assetName;
    int? assetSize;
    String? assetDigest;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      dynamic match;
      final vEscaped = RegExp.escape(rawVersion);
      // Strictly match installer filenames that contain the exact version string
      // e.g. ShopFlow_POS_Setup_v1.2.0-beta.2.exe or ShopFlow_POS_Setup_1.2.0-beta.2.exe
      final exactInstallerPattern = RegExp(
        r'(?:^|[\-_])v?' + vEscaped + r'(?:[\-_.]|\.exe$)',
        caseSensitive: false,
      );

      for (final a in assets) {
        if (a is Map &&
            a['name'] != null &&
            a['name'].toString().toLowerCase().endsWith('.exe') &&
            exactInstallerPattern.hasMatch(a['name'].toString())) {
          match = a;
          break;
        }
      }

      if (match != null && match is Map) {
        downloadUrl = match['browser_download_url']?.toString();
        assetName = match['name']?.toString();
        assetSize = match['size'] is int
            ? match['size'] as int
            : int.tryParse(match['size']?.toString() ?? '');
        final digest = match['digest']?.toString();
        assetDigest = digest?.startsWith('sha256:') == true
            ? digest!.substring('sha256:'.length)
            : digest;
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
      assetDigest: assetDigest,
      isPrerelease: json['prerelease'] == true,
      isDraft: json['draft'] == true,
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

  static int _compareIdentifiers(String a, String b) {
    final aInt = int.tryParse(a);
    final bInt = int.tryParse(b);

    if (aInt != null && bInt != null) {
      return aInt.compareTo(bInt);
    }
    if (aInt != null && bInt == null) {
      // Numeric identifiers have lower precedence than non-numeric in SemVer 2.0
      return -1;
    }
    if (aInt == null && bInt != null) {
      return 1;
    }
    return a.compareTo(b);
  }

  static int _comparePreRelease(String preA, String preB) {
    if (preA == preB) return 0;
    // Release > Pre-release (e.g. 1.2.0 > 1.2.0-beta.1)
    if (preA.isEmpty && preB.isNotEmpty) return 1;
    if (preA.isNotEmpty && preB.isEmpty) return -1;
    if (preA.isEmpty && preB.isEmpty) return 0;

    final partsA = preA.split('.');
    final partsB = preB.split('.');
    final minLen =
        partsA.length < partsB.length ? partsA.length : partsB.length;

    for (int i = 0; i < minLen; i++) {
      final cmp = _compareIdentifiers(partsA[i], partsB[i]);
      if (cmp != 0) return cmp;
    }

    return partsA.length.compareTo(partsB.length);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    final preCmp = _comparePreRelease(preRelease, other.preRelease);
    if (preCmp != 0) return preCmp;

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
  final UpdateChannel? channel;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.release,
    required this.currentVersion,
    this.channel,
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

  /// Checks GitHub releases API for latest valid release on the specified [channel]
  /// and compares with [currentVersionOverride] or [AppConfig.currentVersion].
  static Future<UpdateCheckResult> checkForUpdates({
    UpdateChannel? channel,
    String? currentVersionOverride,
    Duration timeout = const Duration(seconds: 12),
    http.Client? client,
  }) async {
    final targetChannel = channel ?? AppConfig.defaultChannel;
    final currentVerStr = currentVersionOverride ?? AppConfig.currentVersion;
    final currentVer = AppVersion.parse(currentVerStr);
    final httpClient = client ?? _httpClient;

    try {
      final uri = Uri.parse(AppConfig.githubReleasesUrl);
      final response = await httpClient.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'ShopFlow-POS-Desktop',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final listData =
            jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

        final candidateReleases = <AppRelease>[];
        for (final item in listData) {
          if (item is! Map<String, dynamic>) continue;
          final release = AppRelease.fromJson(item);
          if (release.isDraft) continue; // Ignore drafts

          // Channel filtering:
          // Stable channel: ignore pre-releases
          // Beta channel: accept both stable and pre-releases
          if (targetChannel == UpdateChannel.stable && release.isPrerelease) {
            continue;
          }

          candidateReleases.add(release);
        }

        if (candidateReleases.isEmpty) {
          return UpdateCheckResult(
            status: UpdateStatus.upToDate,
            currentVersion: currentVerStr,
            channel: targetChannel,
          );
        }

        // Sort candidate releases by semantic version descending
        candidateReleases.sort((a, b) {
          final verA = AppVersion.parse(a.version);
          final verB = AppVersion.parse(b.version);
          return verB.compareTo(verA);
        });

        final newestRelease = candidateReleases.first;
        final newestVer = AppVersion.parse(newestRelease.version);

        if (newestVer.isGreaterThan(currentVer)) {
          if (newestRelease.assetDownloadUrl == null ||
              newestRelease.assetDownloadUrl!.isEmpty) {
            return UpdateCheckResult(
              status: UpdateStatus.error,
              release: newestRelease,
              currentVersion: currentVerStr,
              channel: targetChannel,
              errorMessage:
                  'New release ${newestRelease.version} is available, but no matching Windows installer (${AppRelease.expectedInstallerFileName(newestRelease.version)}) was found.',
            );
          }
          return UpdateCheckResult(
            status: UpdateStatus.updateAvailable,
            release: newestRelease,
            currentVersion: currentVerStr,
            channel: targetChannel,
          );
        } else {
          return UpdateCheckResult(
            status: UpdateStatus.upToDate,
            release: newestRelease,
            currentVersion: currentVerStr,
            channel: targetChannel,
          );
        }
      } else if (response.statusCode == 403) {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVerStr,
          channel: targetChannel,
          errorMessage:
              'GitHub API rate limit exceeded. Please try again in a few moments.',
        );
      } else {
        return UpdateCheckResult(
          status: UpdateStatus.error,
          currentVersion: currentVerStr,
          channel: targetChannel,
          errorMessage:
              'Server returned code ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on SocketException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVerStr,
        channel: targetChannel,
        errorMessage:
            'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVerStr,
        channel: targetChannel,
        errorMessage: 'Connection timed out while checking for updates.',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: currentVerStr,
        channel: targetChannel,
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
    final downloadUrl = release.assetDownloadUrl;

    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw Exception(
          'No version-matching Windows installer was found for release ${release.version}.');
    }

    // Ensure parent directory exists
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    final partialFile = File('${targetFile.path}.partial');
    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }
    if (await partialFile.exists()) {
      try {
        await partialFile.delete();
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

    final sink = partialFile.openWrite();

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
            try {
              await targetFile.delete();
            } catch (_) {}
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

        final double fraction;
        if (totalBytes > 0) {
          final raw = receivedBytes / totalBytes;
          fraction = raw.isNaN || raw.isInfinite ? 0.0 : raw.clamp(0.0, 1.0);
        } else {
          fraction = 0.0;
        }

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

      if (totalBytes > 0 && receivedBytes != totalBytes) {
        throw Exception(
            'Incomplete download ($receivedBytes of $totalBytes bytes received).');
      }

      await partialFile.rename(targetFile.path);

      yield UpdateDownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes > 0 ? totalBytes : receivedBytes,
        fraction: 1.0,
        statusText: 'Download complete!',
        isCompleted: true,
      );
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      client.close();
      if (await partialFile.exists()) {
        try {
          await partialFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Starts a detached updater. The updater owns the rest of the transaction
  /// because this process must exit before an installed executable can change.
  static Future<bool> relaunchAndInstall(File installerFile,
      {String? expectedVersion, String? expectedDigest}) async {
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
        final appDir =
            p.normalize(File(Platform.resolvedExecutable).parent.path);
        final version =
            expectedVersion ?? _versionFromInstallerName(installerFile);
        final failedMarker = '${installerFile.path}.failed';

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

        final scriptContent = '''# ShopFlow POS Automated Background Updater
\$ErrorActionPreference = 'Stop'
\$installer = ${_psQuote(installerPath)}
\$targetExe = ${_psQuote(appExePath)}
\$targetDir = ${_psQuote(appDir)}
\$expectedVersion = ${_psQuote(version)}
\$expectedDigest = ${_psQuote(expectedDigest ?? '')}
\$failedMarker = ${_psQuote(failedMarker)}
\$tempDir = [System.IO.Path]::GetTempPath()
\$updateDir = Join-Path \$tempDir "ShopFlow_Update"
\$debugLog = Join-Path \$updateDir "ShopFlow_Update_debug.log"
\$innoLog = Join-Path \$updateDir "ShopFlow_Update.log"

function Write-UpdateLog(\$msg) {
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[\$timestamp] [PS-UPDATER] \$msg" | Out-File -FilePath \$debugLog -Append -Encoding utf8
}

Write-UpdateLog "=========================================="
Write-UpdateLog "Starting PowerShell background updater script"
Write-UpdateLog "Target EXE: \$targetExe"
Write-UpdateLog "Installer: \$installer"
Write-UpdateLog "Expected version: \$expectedVersion"

function Fail-Update(\$message) {
    Write-UpdateLog "ERROR: \$message"
    \$message | Out-File -FilePath \$failedMarker -Encoding utf8 -Force
    exit 1
}

if (Test-Path \$failedMarker) { Write-UpdateLog "Refusing repeated attempt for failed installer."; exit 2 }
if (-not (Test-Path \$installer -PathType Leaf)) { Fail-Update "Installer does not exist." }
\$installerInfo = Get-Item \$installer
if (\$installerInfo.Length -lt 1MB) { Fail-Update "Installer is unexpectedly small (\$([int64]\$installerInfo.Length) bytes)." }
if (\$expectedDigest) {
    \$actualDigest = (Get-FileHash -LiteralPath \$installer -Algorithm SHA256).Hash.ToLowerInvariant()
    if (\$actualDigest -ne \$expectedDigest.ToLowerInvariant()) { Fail-Update "Installer SHA-256 mismatch. Expected \$expectedDigest, got \$actualDigest." }
}

# 1. Wait for current Flutter application and PocketBase to completely terminate
Write-UpdateLog "Waiting for app process to exit..."
Start-Sleep -Seconds 2
Get-Process -Name "pos_system" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name "pocketbase" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 2. Execute elevated installer and wait for full completion
Write-UpdateLog "Launching elevated Inno Setup installer..."
\$installerArgs = @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/FORCECLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS=0", "/LOG=`"\$innoLog`"")

try {
    \$proc = Start-Process -FilePath \$installer -ArgumentList \$installerArgs -Verb RunAs -PassThru -Wait
    \$exitCode = \$proc.ExitCode
    Write-UpdateLog "Installer process exited with code: \$exitCode"
    if (\$exitCode -ne 0) { Fail-Update "Installer failed with exit code \$exitCode." }
} catch {
    Fail-Update "Could not run installer elevated: \$_"
}

# 3. Wait for any Inno Setup temporary unpacker child processes (is-*.tmp) to finish
Write-UpdateLog "Checking for child Inno Setup worker processes..."
function Get-DescendantProcessIds(\$parentId) {
    \$children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = \$parentId" -ErrorAction SilentlyContinue)
    foreach (\$child in \$children) {
        Write-Output ([int]\$child.ProcessId)
        Get-DescendantProcessIds ([int]\$child.ProcessId)
    }
}
\$waited = 0
while (\$waited -lt 180) {
    \$installerChildren = @(Get-DescendantProcessIds ([int]\$proc.Id))
    \$innoChild = @(Get-Process -Name "is-*", "Setup" -ErrorAction SilentlyContinue)
    if ((\$installerChildren.Count -eq 0) -and (\$innoChild.Count -eq 0)) { break }
    Start-Sleep -Seconds 1
    \$waited++
}
Write-UpdateLog "Inno Setup worker processes finished (waited \$waited seconds)."

# 4. Resolve installed executable location
if (-not (Test-Path \$targetExe -PathType Leaf)) { Fail-Update "Installed executable is missing: \$targetExe" }
\$installedFile = Get-Item \$targetExe
\$installedVersion = \$installedFile.VersionInfo.ProductVersion
if (-not \$installedVersion.StartsWith(\$expectedVersion)) { Fail-Update "Installed version is \$installedVersion, expected \$expectedVersion." }
\$installedHash = (Get-FileHash -LiteralPath \$targetExe -Algorithm SHA256).Hash
if (-not \$installedHash) { Fail-Update "Could not hash installed executable." }
\$installedTimestamp = \$installedFile.LastWriteTimeUtc.ToString('o')
Write-UpdateLog "Installed executable verified: version=\$installedVersion, timestamp=\$installedTimestamp, sha256=\$installedHash"

# 5. Brief pause to ensure all file handles are fully released by Windows
Start-Sleep -Milliseconds 1000

# 6. Relaunch the upgraded application in standard desktop session
Write-UpdateLog "Relaunching application at: \$targetExe"
if (Test-Path \$targetExe) {
    try {
        \$newProcess = Start-Process -FilePath \$targetExe -WorkingDirectory \$targetDir -PassThru
        Write-UpdateLog "Application launch returned PID \$([int]\$newProcess.Id). Waiting for health..."
        Start-Sleep -Seconds 5
        \$stillRunning = Get-Process -Id \$newProcess.Id -ErrorAction SilentlyContinue
        if (-not \$stillRunning) {
            \$newProcess.Refresh()
            \$processExitCode = \$newProcess.ExitCode
            Fail-Update "Application exited immediately with code \$processExitCode (0x\$('{0:X8}' -f ([uint32]\$processExitCode)))."
        }
        Write-UpdateLog "Application remained running after health window. Update succeeded."
    } catch {
        Fail-Update "Application launch failed: \$_"
    }
} else {
    Fail-Update "Could not find target application at \$targetExe"
}

Write-UpdateLog "Updater script execution complete."
Write-UpdateLog "=========================================="

# 7. Clean up the script file
Remove-Item -Path \$failedMarker -Force -ErrorAction SilentlyContinue
Remove-Item -Path \$PSCommandPath -Force -ErrorAction SilentlyContinue
''';

        await psScriptFile.writeAsString(scriptContent);

        // 3. Launch PowerShell detached to execute the update script silently
        await Process.start(
          'powershell.exe',
          [
            '-NoProfile',
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

  static String _versionFromInstallerName(File installer) {
    final match = RegExp(r'[vV](\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?)')
        .firstMatch(p.basename(installer.path));
    return match?.group(1) ?? 'unknown';
  }

  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
}

class AutoUpdateManager {
  AutoUpdateManager._();
  static final AutoUpdateManager instance = AutoUpdateManager._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  bool _isDialogOpen = false;
  bool get isDialogOpen => _isDialogOpen;

  String? _lastPromptedReleaseVersion;
  String? get lastPromptedReleaseVersion => _lastPromptedReleaseVersion;

  Timer? _pollTimer;
  Timer? _initialCheckTimer;

  void resetSessionPromptState() {
    _lastPromptedReleaseVersion = null;
    _isDialogOpen = false;
    _isChecking = false;
  }

  void startPolling({
    Duration interval = const Duration(minutes: 5),
    Duration initialDelay = const Duration(seconds: 8),
    http.Client? client,
  }) {
    stopPolling();

    _initialCheckTimer = Timer(initialDelay, () {
      checkForUpdatesInBackground(client: client);
    });

    _pollTimer = Timer.periodic(interval, (_) {
      checkForUpdatesInBackground(client: client);
    });
  }

  void stopPolling() {
    _initialCheckTimer?.cancel();
    _initialCheckTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<UpdateCheckResult?> checkForUpdatesInBackground({
    http.Client? client,
  }) async {
    if (_isChecking) return null;

    _isChecking = true;
    try {
      final result = await UpdateService.checkForUpdates(client: client);

      if (result.isUpdateAvailable && result.release != null) {
        final rel = result.release!;
        if (rel.version != _lastPromptedReleaseVersion && !_isDialogOpen) {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            _lastPromptedReleaseVersion = rel.version;
            _isDialogOpen = true;
            try {
              await UpdateDialog.show(
                context,
                release: rel,
                currentVersion: result.currentVersion,
                channel: result.channel,
              );
            } finally {
              _isDialogOpen = false;
            }
          }
        }
      }
      return result;
    } finally {
      _isChecking = false;
    }
  }

  Future<UpdateCheckResult> performManualCheck(
    BuildContext context, {
    http.Client? client,
  }) async {
    if (_isChecking) {
      return UpdateCheckResult(
        status: UpdateStatus.error,
        currentVersion: AppConfig.currentVersion,
        errorMessage: 'An update check is already in progress.',
      );
    }

    _isChecking = true;
    try {
      final result = await UpdateService.checkForUpdates(client: client);

      if (!context.mounted) return result;

      if (result.isUpdateAvailable && result.release != null) {
        if (!_isDialogOpen) {
          _lastPromptedReleaseVersion = result.release!.version;
          _isDialogOpen = true;
          try {
            await UpdateDialog.show(
              context,
              release: result.release!,
              currentVersion: result.currentVersion,
              channel: result.channel,
            );
          } finally {
            _isDialogOpen = false;
          }
        }
      } else if (result.isUpToDate) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: Color(0xFF10B981),
                width: 1.2,
              ),
            ),
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ShopFlow POS is up to date',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current version v${result.currentVersion} (${result.channel?.displayName ?? "Beta"} channel) is the latest.',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (result.hasError) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1.2,
              ),
            ),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Check Failed',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.errorMessage ??
                            'Unable to connect to update server.',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return result;
    } finally {
      _isChecking = false;
    }
  }
}
