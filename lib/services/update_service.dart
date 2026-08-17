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

    String? downloadUrl;
    String? assetName;
    int? assetSize;
    String? assetDigest;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      dynamic match;
      final vEscaped = RegExp.escape(rawVersion);
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
      return -1;
    }
    if (aInt == null && bInt != null) {
      return 1;
    }
    return a.compareTo(b);
  }

  static int _comparePreRelease(String preA, String preB) {
    if (preA == preB) return 0;
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

/// Result of checking whether the previous background update attempt failed.
/// Call [UpdateService.checkForPreviousUpdateFailure] once at app startup
/// (e.g. in main() after the first frame) and surface [message] to the user
/// if [failed] is true, so a failed silent update is no longer invisible.
class PreviousUpdateFailure {
  final bool failed;
  final String? message;
  const PreviousUpdateFailure({required this.failed, this.message});
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
          if (release.isDraft) continue;

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

    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    final partialFile = File('${targetFile.path}.partial');
    final failedMarker = File('${targetFile.path}.failed');
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
    if (await failedMarker.exists()) {
      try {
        await failedMarker.delete();
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

  /// Generates the contents of the PowerShell updater script.
  ///
  /// The updater owns the complete transaction after the Flutter process exits.
  /// Inno Setup skips its [Run] entry for /VERYSILENT, so restart must happen
  /// here and must be verified before the updater reports success.
  static String generateUpdaterScriptContent({
    required String installerPath,
    required String targetExePath,
    required String expectedVersion,
    String? expectedDigest,
    required String failedMarkerPath,
    required String debugLogPath,
    required String innoLogPath,
    required String errorLogPath,
    String? startupMarkerPath,
    String? transactionConfigPath,
  }) {
    final installer = _psQuote(installerPath);
    final targetExe = _psQuote(targetExePath);
    final expVersion = _psQuote(expectedVersion);
    final expDigest = _psQuote(expectedDigest ?? '');
    final failedMk = _psQuote(failedMarkerPath);
    final dbgLog = _psQuote(debugLogPath);
    final innoL = _psQuote(innoLogPath);
    final errLog = _psQuote(errorLogPath);
    final startupMk = _psQuote(startupMarkerPath ?? '');
    final configPath = _psQuote(transactionConfigPath ?? '');
    return '''# ShopFlow POS Automated Background Updater
\$ErrorActionPreference = 'Continue'
\$installer = $installer
\$targetExe = $targetExe
\$expectedVersion = $expVersion
\$expectedDigest = $expDigest
\$failedMarker = $failedMk
\$debugLog = $dbgLog
\$innoLog = $innoL
\$errorLog = $errLog
\$startupMarker = $startupMk
\$transactionConfig = $configPath

if (\$transactionConfig -and (Test-Path -LiteralPath \$transactionConfig -PathType Leaf)) {
    try {
        \$transaction = Get-Content -LiteralPath \$transactionConfig -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        \$installer = [string]\$transaction.installerPath
        \$targetExe = [string]\$transaction.targetExePath
        \$expectedVersion = [string]\$transaction.expectedVersion
        \$expectedDigest = [string]\$transaction.expectedDigest
        \$failedMarker = [string]\$transaction.failedMarkerPath
        \$debugLog = [string]\$transaction.debugLogPath
        \$innoLog = [string]\$transaction.innoLogPath
        \$errorLog = [string]\$transaction.errorLogPath
        \$startupMarker = [string]\$transaction.startupMarkerPath
    } catch {
        # The embedded values remain the safe fallback if metadata is unreadable.
    }
}

function Write-UpdateLog(\$msg) {
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[\$timestamp] [PS-UPDATER] \$msg" | Out-File -FilePath \$debugLog -Append -Encoding utf8 -ErrorAction SilentlyContinue
}

function Get-FileProductVersion(\$path) {
    try {
        if (Test-Path \$path -PathType Leaf) {
            return (Get-Item -LiteralPath \$path).VersionInfo.ProductVersion
        }
    } catch {}
    return \$null
}

function Fail-Update(\$msg) {
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-UpdateLog "FATAL ERROR: \$msg"
    "[\$timestamp] FATAL: \$msg" | Out-File -FilePath \$errorLog -Append -Encoding utf8 -ErrorAction SilentlyContinue
    \$msg | Out-File -FilePath \$failedMarker -Encoding utf8 -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-UpdateLog "=========================================="
\$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
\$principal = New-Object System.Security.Principal.WindowsPrincipal(\$identity)
\$isAdmin = \$principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
\$elevation = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name ConsentPromptBehaviorAdmin -ErrorAction SilentlyContinue).ConsentPromptBehaviorAdmin
Write-UpdateLog "Stage 1/7: PowerShell updater started (PID: \$PID, ParentPID: \$((Get-CimInstance Win32_Process -Filter "ProcessId = \$PID").ParentProcessId), Identity: \$((\$identity).Name), Elevated: \$isAdmin, ConsentPromptBehaviorAdmin: \$elevation)"
Write-UpdateLog "Installer path : \$installer"
Write-UpdateLog "Target EXE     : \$targetExe"
Write-UpdateLog "Expected ver   : \$expectedVersion"
Write-UpdateLog "Expected SHA256: \$expectedDigest"

# Verify the downloaded installer before UAC handoff. This keeps the hash
# operation in the original updater process, before the Flutter application
# exits and before the elevated child takes ownership of the transaction.
if (-not (Test-Path \$installer -PathType Leaf)) {
    Fail-Update "Installer file not found: \$installer"
}
if (\$expectedDigest -and \$expectedDigest.Trim() -ne "") {
    Write-UpdateLog "Verifying installer SHA-256 before elevation..."
    try {
        \$actualDigest = (Get-FileHash -LiteralPath \$installer -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        Write-UpdateLog "Computed SHA-256: \$actualDigest"
    } catch {
        Fail-Update "Failed to compute SHA-256 before elevation: \$_"
    }
    if (\$actualDigest -ne \$expectedDigest.ToLowerInvariant()) {
        Fail-Update "SHA-256 mismatch. Expected: \$expectedDigest  Got: \$actualDigest"
    }
    Write-UpdateLog "SHA-256 verified OK before elevation"
}

if (-not \$isAdmin) {
    Write-UpdateLog "Updater is not elevated. Re-launching itself with UAC before process shutdown."
    try {
        \$selfPowerShell = Join-Path \$env:WINDIR 'System32\\WindowsPowerShell\\v1.0\\powershell.exe'
        \$selfArguments = @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            "`"\$PSCommandPath`""
        )
        \$selfWorkingDirectory = Split-Path -Parent \$PSCommandPath
        Write-UpdateLog "Elevation executable: \$selfPowerShell"
        Write-UpdateLog "Elevation script path: \$PSCommandPath"
        Write-UpdateLog "Elevation arguments: \$((\$selfArguments -join ' '))"
        Write-UpdateLog "Elevation working directory: \$selfWorkingDirectory"
        \$elevatedUpdater = Start-Process -FilePath \$selfPowerShell -ArgumentList \$selfArguments -WorkingDirectory \$selfWorkingDirectory -Verb RunAs -PassThru -ErrorAction Stop
        \$elevatedPid = \$elevatedUpdater.Id
        Write-UpdateLog "Elevated updater dispatched (PID: \$elevatedPid). The non-elevated updater is exiting."
        \$elevatedRunning = \$null
        for (\$elevationWait = 0; \$elevationWait -lt 20; \$elevationWait++) {
            Start-Sleep -Milliseconds 500
            \$elevatedRunning = Get-Process -Id \$elevatedPid -ErrorAction SilentlyContinue
            if (\$elevatedRunning) { break }
        }
        Write-UpdateLog "Elevated child running after dispatch: \$([bool]\$elevatedRunning)"
        if (-not \$elevatedRunning) {
            Fail-Update "Elevated updater PID \$elevatedPid exited before reaching the updater script."
        }
        exit 0
    } catch {
        Fail-Update "Could not elevate updater before terminating ShopFlow: \$_"
    }
}

if (\$startupMarker -and \$startupMarker.Trim() -ne '') {
    Set-Content -LiteralPath \$startupMarker -Value 'Updater script started after elevation' -Encoding utf8 -Force
}

# ----- Pre-flight checks -----
if (Test-Path \$failedMarker) {
    Write-UpdateLog "Stale .failed marker found -- clearing it and proceeding"
    Remove-Item -Path \$failedMarker -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path \$installer -PathType Leaf)) {
    Fail-Update "Installer file not found: \$installer"
}

\$installerInfo = Get-Item -LiteralPath \$installer
Write-UpdateLog "Installer size : \$(\$installerInfo.Length) bytes"

if (\$installerInfo.Length -lt 1MB) {
    Fail-Update "Installer file is unexpectedly small (\$([int64]\$installerInfo.Length) bytes) -- download may be corrupt"
}

# ----- Stage 2: Record current installed version BEFORE update -----
Write-UpdateLog "Stage 2/7: Recording pre-update version..."
\$versionBefore = Get-FileProductVersion \$targetExe
Write-UpdateLog "Version BEFORE update: \$(if (\$versionBefore) { \$versionBefore } else { '(not installed / unreadable)' })"

# ----- Stage 3: Wait briefly, then explicitly terminate old processes -----
\$targetDir = [System.IO.Path]::GetDirectoryName(\$targetExe)

function Get-TrackedProcesses() {
    \$tracked = @()
    foreach (\$process in @(Get-Process -Name "pos_system","pocketbase" -ErrorAction SilentlyContinue)) {
        \$path = \$null
        try { \$path = \$process.Path } catch { }
        \$isShopFlowApp = \$process.Name -eq 'pos_system' -and \$path -and [System.IO.Path]::GetFullPath(\$path) -ieq [System.IO.Path]::GetFullPath(\$targetExe)
        \$isShopFlowPocketBase = \$process.Name -eq 'pocketbase' -and \$path -and [System.IO.Path]::GetFullPath(\$path).StartsWith([System.IO.Path]::GetFullPath(\$targetDir), [System.StringComparison]::OrdinalIgnoreCase)
        if (\$isShopFlowApp -or \$isShopFlowPocketBase) { \$tracked += \$process }
    }
    return @(\$tracked)
}

function Write-TrackedProcessDiagnostics(\$label) {
    \$tracked = Get-TrackedProcesses
    if (-not \$tracked) {
        Write-UpdateLog "Stage 3 diagnostics (\$label): no ShopFlow processes found."
        return
    }
    foreach (\$process in \$tracked) {
        \$path = '(path unavailable)'
        try { \$path = \$process.Path } catch { }
        Write-UpdateLog "Stage 3 diagnostics (\$label): Name=\$((\$process).Name), PID=\$((\$process).Id), Path=\$path"
    }
}

Write-UpdateLog "Stage 3/7: Waiting up to 5 seconds for old ShopFlow processes to exit..."
Write-UpdateLog "Stage 3 updater PID: \$PID, Elevated: \$isAdmin"
Write-TrackedProcessDiagnostics 'initial'
\$initialTracked = @(Get-TrackedProcesses)
\$trackedPids = @(
    \$initialTracked | ForEach-Object { [int]\$_.Id }
)
Write-UpdateLog "Stage 3 tracked PIDs: \$((\$trackedPids -join ', '))"
\$maxWait = 5
Write-UpdateLog "  Graceful wait (0/\$maxWait s): cached ShopFlow PIDs"
Start-Sleep -Seconds \$maxWait
Write-UpdateLog "Stage 3 graceful wait finished after \$maxWait seconds."

foreach (\$trackedPid in \$trackedPids) {
    try {
        Write-UpdateLog "Stage 3 termination attempt: PID=\$trackedPid"
        # Do not use /T: the updater is launched from the old app process tree,
        # so killing descendants would terminate this updater as well.
        \$taskkillOutput = & taskkill.exe /PID \$trackedPid /F 2>&1
        \$taskkillExitCode = \$LASTEXITCODE
        Write-UpdateLog "Stage 3 termination result: PID=\$trackedPid ExitCode=\$taskkillExitCode Output=\$((\$taskkillOutput -join ' ').Trim())"
        if (\$taskkillExitCode -ne 0 -and \$taskkillExitCode -ne 128) {
            Fail-Update "Stage 3 termination failed for PID \$trackedPid. taskkill exit code \${taskkillExitCode}: \$((\$taskkillOutput -join ' ').Trim())"
        }
    } catch {
        Fail-Update "Stage 3 termination failed for PID \${trackedPid}: \$_"
    }
}

Start-Sleep -Milliseconds 500
\$remainingPids = @()
foreach (\$trackedPid in \$trackedPids) {
    \$tasklistOutput = & tasklist.exe /FI "PID eq \$trackedPid" /NH 2>&1
    if ((\$tasklistOutput -join "`n") -match "\b\$trackedPid\s+") {
        \$remainingPids += \$trackedPid
    }
}
Write-UpdateLog "Stage 3 final PID verification: \$((\$remainingPids -join ', '))"
if (\$remainingPids.Count -gt 0) {
    Fail-Update "Stage 3 final verification failed; ShopFlow PIDs remain: \$((\$remainingPids -join ', '))"
}
Write-UpdateLog "Stage 3 complete: old processes confirmed exited; proceeding to Stage 4."

# ----- Stage 4: Run installer elevated and wait for completion -----
Write-UpdateLog "Stage 4/7: Launching installer with UAC elevation..."
Write-UpdateLog "  Path: \$installer"
\$installerArgs = "/VERYSILENT /SUPPRESSMSGBOXES /FORCECLOSEAPPLICATIONS /NORESTART /LOG=`"\$innoLog`""
Write-UpdateLog "  Args: \$installerArgs"

try {
    # -Wait is essential: process-name polling misses Inno's elevated child
    # (often renamed to an is-*.tmp process) and can race file replacement.
    \$installerProcess = Start-Process -FilePath \$installer -ArgumentList \$installerArgs -Verb RunAs -PassThru -Wait -ErrorAction Stop
    \$installerExitCode = \$installerProcess.ExitCode
    Write-UpdateLog "Stage 4/7: Installer completed (PID: \$((\$installerProcess).Id), ExitCode: \$installerExitCode)."
    if (\$installerExitCode -ne 0) {
        Fail-Update "Installer returned non-success exit code \$installerExitCode. See Inno log: \$innoLog"
    }
} catch {
    Fail-Update "Exception launching/waiting for installer (UAC denied or setup failed): \$_"
}

# ----- Stage 5: Verify new executable and expected version -----
Write-UpdateLog "Stage 5/7: Verifying updated executable on disk..."
Start-Sleep -Seconds 2

if (-not (Test-Path \$targetExe -PathType Leaf)) {
    Fail-Update "pos_system.exe missing after installer ran: \$targetExe"
}

\$versionAfter = Get-FileProductVersion \$targetExe
\$installedVersion = \$versionAfter
Write-UpdateLog "Version AFTER update: \$(if (\$versionAfter) { \$versionAfter } else { '(unreadable)' })"

if (\$expectedVersion -and \$expectedVersion.Trim() -ne "" -and \$versionAfter) {
    \$cleanExpected = (\$expectedVersion -replace '[+].*','').Trim()
    \$cleanActual   = (\$versionAfter   -replace '[+].*','').Trim()
    if (-not \$cleanActual.StartsWith(\$cleanExpected)) {
        Fail-Update "Installed version (\$installedVersion) does not match expected version (\$expectedVersion). Stale binary detected."
    }
    Write-UpdateLog "Version verified successfully: \$versionAfter"
}

# ----- Stage 6: Restart pos_system.exe from detached updater -----
Write-UpdateLog "Stage 6/7: Restarting pos_system.exe from detached updater..."
Write-UpdateLog "  Target EXE: \$targetExe"
\$targetDir = [System.IO.Path]::GetDirectoryName(\$targetExe)
try {
    \$proc = Start-Process -FilePath \$targetExe -WorkingDirectory \$targetDir -PassThru -ErrorAction Stop
    Write-UpdateLog "  Restart dispatched directly (PID: \$(\$proc.Id))"
} catch {
    Fail-Update "Direct restart failed: \$_"
}

# Monitoring startup health...
Write-UpdateLog "Monitoring startup health..."
\$runningProcs = \$null
for (\$i = 0; \$i -lt 20; \$i++) {
    Start-Sleep -Milliseconds 500
    \$runningProcs = Get-Process -Name "pos_system" -ErrorAction SilentlyContinue
    if (\$runningProcs) { break }
}
if (-not \$runningProcs) {
    Fail-Update "Restart dispatched but pos_system.exe is not running after 10 seconds."
}
Write-UpdateLog "Restart SUCCESS: pos_system.exe running (PID: \$((\$runningProcs | ForEach-Object { \$_.Id }) -join ', '))"

# ----- Stage 7: Cleanup -----
Write-UpdateLog "Stage 7/7: Cleaning up temporary files..."
Remove-Item -Path \$failedMarker -Force -ErrorAction SilentlyContinue
Remove-Item -Path \$PSCommandPath -Force -ErrorAction SilentlyContinue
Write-UpdateLog "UPDATE TRANSACTION COMPLETE. \$versionBefore -> \$versionAfter"
Write-UpdateLog "=========================================="
''';
  }

  /// Starts an independent background updater. The updater owns the rest of
  /// the transaction because this process must exit before an installed
  /// executable can change. The updater handles graceful waiting, installation,
  /// verification, and automatic relaunch of pos_system.exe.
  static Future<bool> relaunchAndInstall(
    File installerFile, {
    String? expectedVersion,
    String? expectedDigest,
    String? targetExePathOverride,
  }) async {
    if (!await installerFile.exists()) {
      return false;
    }

    try {
      if (!kIsWeb && Platform.isWindows) {
        final transactionId =
            '${DateTime.now().toUtc().microsecondsSinceEpoch}_${installerFile.lengthSync()}';
        final updateRoot = Directory(
          p.join(Directory.systemTemp.path, 'ShopFlow_Update'),
        );
        final updateDir = Directory(p.join(updateRoot.path, transactionId));
        updateDir.createSync(recursive: true);

        final transactionInstaller = File(
          p.join(updateDir.path, p.basename(installerFile.path)),
        );
        await installerFile.copy(transactionInstaller.path);
        final installerPath = p.normalize(transactionInstaller.absolute.path);
        final appExePath = targetExePathOverride != null
            ? p.normalize(targetExePathOverride)
            : p.normalize(Platform.resolvedExecutable);

        final version =
            expectedVersion ?? _versionFromInstallerName(installerFile);

        final failedMarkerPath = '${transactionInstaller.path}.failed';

        final debugLogPath = p.join(
          updateDir.path,
          'ShopFlow_Update_debug.log',
        );
        final innoLogPath = p.join(
          updateDir.path,
          'ShopFlow_Update.log',
        );
        final errorLogPath = p.join(
          updateDir.path,
          'ShopFlow_Update_error.log',
        );
        final updaterScriptPath = p.join(
          updateDir.path,
          'update_runner.ps1',
        );
        final transactionConfigPath = p.join(
          updateDir.path,
          'update_transaction.json',
        );
        final updaterStartedMarkerPath = '$updaterScriptPath.started';
        final updaterPidPath = '$updaterStartedMarkerPath.pid';

        final timestamp = DateTime.now().toIso8601String();

        void writeLauncherLog(String message) {
          try {
            File(debugLogPath).writeAsStringSync(
              '[$timestamp] [DART-LAUNCHER] $message\n',
              mode: FileMode.append,
              flush: true,
            );
          } catch (_) {}
        }

        writeLauncherLog('==========================================');
        writeLauncherLog('Initiate update transaction');
        writeLauncherLog('Installer: $installerPath');
        writeLauncherLog('TargetExe: $appExePath');
        writeLauncherLog('ExpectedVersion: $version');
        writeLauncherLog('ExpectedSHA256: ${expectedDigest ?? "None"}');

        final transactionConfig = <String, dynamic>{
          'installerPath': installerPath,
          'targetExePath': appExePath,
          'targetDir': p.dirname(appExePath),
          'expectedVersion': version,
          'expectedDigest': expectedDigest ?? '',
          'failedMarkerPath': failedMarkerPath,
          'debugLogPath': debugLogPath,
          'innoLogPath': innoLogPath,
          'errorLogPath': errorLogPath,
          'startupMarkerPath': updaterStartedMarkerPath,
        };
        File(transactionConfigPath).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(transactionConfig),
          mode: FileMode.writeOnly,
          flush: true,
        );
        writeLauncherLog('Transaction metadata: $transactionConfigPath');

        final updaterScriptContent = generateUpdaterScriptContent(
          installerPath: installerPath,
          targetExePath: appExePath,
          expectedVersion: version,
          expectedDigest: expectedDigest,
          failedMarkerPath: failedMarkerPath,
          debugLogPath: debugLogPath,
          innoLogPath: innoLogPath,
          errorLogPath: errorLogPath,
          startupMarkerPath: updaterStartedMarkerPath,
          transactionConfigPath: transactionConfigPath,
        );

        File(updaterScriptPath).writeAsStringSync(
          updaterScriptContent,
          mode: FileMode.writeOnly,
          flush: true,
        );
        try {
          final marker = File(updaterStartedMarkerPath);
          if (marker.existsSync()) marker.deleteSync();
          final pidFile = File(updaterPidPath);
          if (pidFile.existsSync()) pidFile.deleteSync();
        } catch (_) {}

        writeLauncherLog('Update runner script generated: $updaterScriptPath');
        writeLauncherLog(
            'Updater script exists: ${File(updaterScriptPath).existsSync()}, size: ${File(updaterScriptPath).lengthSync()} bytes');
        writeLauncherLog(
            'Startup marker: $updaterStartedMarkerPath (exists: ${File(updaterStartedMarkerPath).existsSync()})');
        final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
        final powershellCandidate = p.join(
          systemRoot,
          'System32',
          'WindowsPowerShell',
          'v1.0',
          'powershell.exe',
        );
        final powershellExecutable = File(powershellCandidate).existsSync()
            ? powershellCandidate
            : 'powershell.exe';
        writeLauncherLog('PowerShell executable: $powershellExecutable');
        final updaterArguments = [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          updaterScriptPath,
        ];
        writeLauncherLog('Updater script arguments: $updaterArguments');
        writeLauncherLog('Updater working directory: ${updateDir.path}');
        final updaterArgumentString =
            '-NoProfile -ExecutionPolicy Bypass -File "$updaterScriptPath"';
        final launcherCommand =
            '\$child = Start-Process -FilePath ${_psQuote(powershellExecutable)} -ArgumentList ${_psQuote(updaterArgumentString)} -WorkingDirectory ${_psQuote(updateDir.path)} -PassThru -WindowStyle Hidden; Set-Content -LiteralPath ${_psQuote(updaterPidPath)} -Value \$child.Id -Encoding ascii -Force';
        final launcherArguments = [
          '-WindowStyle',
          'Hidden',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          launcherCommand,
        ];
        writeLauncherLog(
            'Launch mechanism: Windows PowerShell Start-Process (independent child)');
        writeLauncherLog('Launcher arguments: $launcherArguments');

        late final Process updaterProcess;
        try {
          updaterProcess = await Process.start(
            powershellExecutable,
            launcherArguments,
            mode: ProcessStartMode.normal,
            workingDirectory: updateDir.path,
          );
        } catch (e) {
          writeLauncherLog('FAILED to start detached updater: $e');
          rethrow;
        }

        writeLauncherLog(
            'PROCESS CREATED: Windows launcher dispatched (PID: ${updaterProcess.pid}).');

        Future<String> childProcessState() async {
          try {
            final exitCode = await updaterProcess.exitCode
                .timeout(const Duration(milliseconds: 100));
            return 'PROCESS EXITED (exit code: $exitCode)';
          } catch (_) {}

          try {
            final taskList = await Process.run(
              'tasklist.exe',
              ['/FI', 'PID eq ${updaterProcess.pid}', '/NH'],
            );
            final output = '${taskList.stdout}\n${taskList.stderr}';
            if (output.contains('${updaterProcess.pid}')) {
              return 'PROCESS STILL RUNNING';
            }
            return 'PROCESS NOT FOUND (exit code unavailable)';
          } catch (e) {
            return 'PROCESS STATE UNKNOWN ($e)';
          }
        }

        await Future<void>.delayed(const Duration(milliseconds: 500));
        writeLauncherLog('After 500 ms: ${await childProcessState()}');
        await Future<void>.delayed(const Duration(seconds: 1));
        writeLauncherLog('After 1.5 s: ${await childProcessState()}');
        await Future<void>.delayed(const Duration(seconds: 2));
        writeLauncherLog('After 3.5 s: ${await childProcessState()}');

        var updaterStarted = false;
        for (var i = 0; i < 150; i++) {
          if (File(updaterStartedMarkerPath).existsSync()) {
            updaterStarted = true;
            writeLauncherLog('MARKER CREATED: $updaterStartedMarkerPath');
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (!updaterStarted) {
          int? childExitCode;
          try {
            childExitCode = await updaterProcess.exitCode
                .timeout(const Duration(seconds: 1));
          } catch (_) {}
          writeLauncherLog(
              'MARKER NOT CREATED: detached updater PID ${updaterProcess.pid}; ${childExitCode == null ? "PROCESS STILL RUNNING OR EXIT CODE UNAVAILABLE" : "PROCESS EXITED + EXIT CODE $childExitCode"}. Flutter process will remain running.');
          return false;
        }
        writeLauncherLog(
            'MARKER CREATED: independent updater PID ${File(updaterPidPath).existsSync() ? File(updaterPidPath).readAsStringSync().trim() : "unavailable"}. Updater will terminate ShopFlow during Stage 3.');

        // Do not call exit(0) here. On this Windows runtime, terminating the
        // Flutter process immediately after the marker can also terminate the
        // elevated updater child before Stage 3. The updater owns shutdown and
        // will terminate pos_system.exe itself before launching the installer.
        return true;
      }

      await launchUrl(
        Uri.file(installerFile.path),
        mode: LaunchMode.externalApplication,
      );

      return true;
    } catch (e) {
      debugPrint('Error launching installer: $e');
      return false;
    }
  }

  /// Call once at app startup (e.g. after the first frame in main.dart) to
  /// find out whether the last background update attempt failed. Previously
  /// this information was written to a .failed marker + error log but never
  /// read back by the app, so a failed silent update was invisible to the
  /// user. Deletes the marker after reading so it's only reported once.
  static Future<PreviousUpdateFailure> checkForPreviousUpdateFailure() async {
    if (kIsWeb || !Platform.isWindows) {
      return const PreviousUpdateFailure(failed: false);
    }
    try {
      final updateDir = Directory(
        p.join(Directory.systemTemp.path, 'ShopFlow_Update'),
      );
      if (!updateDir.existsSync()) {
        return const PreviousUpdateFailure(failed: false);
      }

      // .failed markers are written next to the installer as
      // "<installer>.failed" -- scan for any such file left over.
      final failedMarkers = updateDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.failed'))
          .toList();

      if (failedMarkers.isEmpty) {
        return const PreviousUpdateFailure(failed: false);
      }

      final marker = failedMarkers.first;
      String message = 'The last update attempt did not complete.';
      try {
        final content = marker.readAsStringSync().trim();
        if (content.isNotEmpty) message = content;
      } catch (_) {}

      try {
        marker.deleteSync();
      } catch (_) {}

      return PreviousUpdateFailure(failed: true, message: message);
    } catch (e) {
      debugPrint('checkForPreviousUpdateFailure error: $e');
      return const PreviousUpdateFailure(failed: false);
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
