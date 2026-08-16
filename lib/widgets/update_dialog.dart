import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_config.dart';
import '../core/theme/cafe_colors.dart';
import '../core/theme/nova_theme.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppRelease release;
  final String currentVersion;
  final UpdateChannel? channel;

  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
    this.channel,
  });

  static Future<void> show(
    BuildContext context, {
    required AppRelease release,
    String? currentVersion,
    UpdateChannel? channel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => UpdateDialog(
        release: release,
        currentVersion: currentVersion ?? AppConfig.currentVersion,
        channel: channel ?? AppConfig.defaultChannel,
      ),
    );
  }

  static Future<void> showUpToDateDialog(
    BuildContext context, {
    String? currentVersion,
  }) {
    final ver = currentVersion ?? AppConfig.currentVersion;
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NovaColors.borderTertiary, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: NovaColors.tealLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NovaColors.teal.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: NovaColors.teal,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "You're Up to Date!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: NovaColors.textPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: NovaColors.bgSecondary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: NovaColors.borderTertiary),
                ),
                child: Text(
                  'ShopFlow POS v$ver is the latest version available.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: NovaColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeColors.flame,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Great',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showErrorDialog(
    BuildContext context, {
    required String errorMessage,
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NovaColors.bgPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: NovaColors.borderTertiary, width: 1),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: NovaColors.dangerLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NovaColors.danger.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: NovaColors.danger,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Update Check Failed',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: NovaColors.textPrimary,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: NovaColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: NovaColors.borderTertiary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          color: NovaColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          onRetry();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CafeColors.flame,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isLaunching = false;
  String? _errorMessage;
  double _downloadFraction = 0.0;
  String _downloadStatus = '';
  String _formattedReceived = '';
  String _formattedTotal = '';
  File? _downloadedFile;
  StreamSubscription<UpdateDownloadProgress>? _downloadSub;
  UpdateDownloadCancelToken? _cancelToken;

  // FIX: the header close (X) button previously only checked _isDownloading,
  // so a user could dismiss the dialog while relaunchAndInstall() was
  // mid-flight (PocketBase shutdown, writing update_runner.ps1, launching
  // the detached PowerShell process). Dismissing didn't actually stop that
  // work -- it's an in-flight await, not tied to widget lifecycle -- but the
  // UI gave no indication anything was still happening. This flag gates the
  // close button for the one operation that's about to terminate the app.
  bool get _isBusy => _isDownloading || _isLaunching;

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _isDownloaded = false;
      _errorMessage = null;
      _downloadFraction = 0.0;
      _downloadStatus = 'Initializing download...';
    });

    final targetFile = UpdateService.getTempInstallerFile(
      assetName: widget.release.assetName,
      version: widget.release.version,
    );

    _cancelToken = UpdateDownloadCancelToken();

    _downloadSub = UpdateService.downloadReleaseAsset(
      release: widget.release,
      targetFile: targetFile,
      cancelToken: _cancelToken,
    ).listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _downloadFraction = progress.fraction;
          _downloadStatus = progress.statusText;
          _formattedReceived = progress.formattedReceived;
          _formattedTotal = progress.formattedTotal;
          if (progress.isCompleted) {
            _isDownloading = false;
            _isDownloaded = true;
            _downloadedFile = targetFile;
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _isDownloaded = false;
          _errorMessage = error.toString().replaceAll('Exception: ', '');
        });
      },
      cancelOnError: true,
    );
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    _downloadSub?.cancel();
    setState(() {
      _isDownloading = false;
      _downloadFraction = 0.0;
      _downloadStatus = 'Download cancelled';
    });
  }

  Future<void> _handleRelaunch() async {
    if (_downloadedFile == null || !await _downloadedFile!.exists()) {
      setState(() {
        _errorMessage =
            'Downloaded update file was not found. Please try downloading again.';
        _isDownloaded = false;
      });
      return;
    }

    setState(() => _isLaunching = true);

    // NOTE: on success this call ends with exit(0) inside UpdateService --
    // the process is gone before it would ever return true, so "success"
    // has no visible UI state here. This branch only ever fires for a
    // genuine early failure (installer missing, or an exception thrown
    // before the process exits).
    final success = await UpdateService.relaunchAndInstall(
      _downloadedFile!,
      expectedVersion: widget.release.version,
      expectedDigest: widget.release.assetDigest,
    );
    if (!success && mounted) {
      setState(() {
        _isLaunching = false;
        _errorMessage =
            'Failed to launch installer automatically. Please run the downloaded file from: ${_downloadedFile!.path}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 540;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: 24,
      ),
      child: Center(
        child: Container(
          width: 520,
          decoration: BoxDecoration(
            color: NovaColors.bgPrimary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: NovaColors.borderTertiary,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Premium Gradient Header
                _buildHeader(context),

                // 2. Main Content Body
                Padding(
                  padding: EdgeInsets.all(isCompact ? 16 : 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Version Comparison Pill Banner
                      _buildVersionComparisonBanner(),

                      const SizedBox(height: 16),

                      // Release Details & Release Notes Section
                      _buildReleaseNotesSection(theme),

                      const SizedBox(height: 16),

                      // Download Progress / Status State Section
                      if (_isDownloading)
                        _buildDownloadingState()
                      else if (_isDownloaded)
                        _buildDownloadedState()
                      else if (_errorMessage != null)
                        _buildErrorState(),

                      const SizedBox(height: 20),

                      // Action Buttons Area (Update, Relaunch, Later)
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: CafeColors.headerGradient,
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Software Update Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'A new version of ShopFlow POS is ready to install',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _isBusy ? 'Please wait...' : 'Close',
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionComparisonBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Row(
        children: [
          // Current Version Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INSTALLED VERSION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: NovaColors.textTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'v${widget.currentVersion}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NovaColors.borderTertiary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: NovaColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrow Indicator
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: NovaColors.violetLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: NovaColors.violet,
            ),
          ),

          const SizedBox(width: 14),

          // New Version Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LATEST RELEASE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: NovaColors.textTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'v${widget.release.version}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: NovaColors.violet,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: NovaColors.tealLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: NovaColors.tealDeep,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseNotesSection(ThemeData theme) {
    final release = widget.release;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metadata chips (Date, Size)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildMetaChip(
              icon: Icons.alt_route_rounded,
              label: widget.release.isPrerelease
                  ? 'Beta Channel'
                  : 'Stable Channel',
            ),
            if (release.formattedPublishedDate.isNotEmpty)
              _buildMetaChip(
                icon: Icons.calendar_today_rounded,
                label: release.formattedPublishedDate,
              ),
            if (release.formattedSize.isNotEmpty)
              _buildMetaChip(
                icon: Icons.folder_zip_rounded,
                label: release.formattedSize,
              ),
          ],
        ),

        const SizedBox(height: 10),

        // "What's New" Label
        const Text(
          "What's New in this Version:",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: NovaColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        // Scrollable Notes Box
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NovaColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NovaColors.borderTertiary),
          ),
          child: SingleChildScrollView(
            child: Text(
              release.body.trim().isNotEmpty
                  ? release.body.trim()
                  : '• Performance and stability enhancements\n• Production updates and bug fixes\n• Modernized user experience',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: NovaColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NovaColors.borderTertiary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: NovaColors.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: NovaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingState() {
    final pct = (_downloadFraction * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.violetLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.violet.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _downloadStatus,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NovaColors.violetDeep,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: NovaColors.violetDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _downloadFraction > 0 ? _downloadFraction : null,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(CafeColors.flame),
              minHeight: 8,
            ),
          ),
          if (_formattedReceived.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_formattedReceived / $_formattedTotal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NovaColors.violetDeep.withOpacity(0.8),
                  ),
                ),
                GestureDetector(
                  onTap: _cancelDownload,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: NovaColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadedState() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaColors.tealLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.teal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: NovaColors.teal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Ready to Install',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: NovaColors.tealDeep,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Click Relaunch to restart and apply this update.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: NovaColors.tealDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NovaColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: NovaColors.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'An error occurred during update.',
              style: const TextStyle(
                fontSize: 12,
                color: NovaColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // 1. Downloading state buttons
    if (_isDownloading) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelDownload,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: NovaColors.borderTertiary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: NovaColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeColors.flame,
                disabledBackgroundColor: CafeColors.flame.withOpacity(0.6),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              label: const Text(
                'Downloading...',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2. Downloaded state (Ready to Relaunch)
    if (_isDownloaded) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              // FIX: also disabled while _isLaunching, matching the header
              // close button -- previously this stayed tappable during the
              // relaunch/install sequence.
              onPressed:
                  _isLaunching ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: NovaColors.borderTertiary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Later',
                style: TextStyle(
                  color: NovaColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [NovaColors.teal, Color(0xFF137A5B)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: NovaColors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLaunching ? null : _handleRelaunch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isLaunching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.restart_alt_rounded, size: 20),
                label: Text(
                  _isLaunching ? 'Relaunching...' : 'Relaunch Now',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 3. Initial State (Update Available)
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: NovaColors.borderTertiary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Later',
              style: TextStyle(
                color: NovaColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: CafeColors.headerGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CafeColors.flame.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                'Update Now',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
