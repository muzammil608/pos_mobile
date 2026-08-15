import 'package:flutter/material.dart';

import '../core/constants/app_config.dart';
import '../core/utils/clickable_cursor.dart';
import '../services/update_service.dart';

class AppUpdateButton extends StatefulWidget {
  final bool compact;
  final Color? color;
  final double iconSize;

  const AppUpdateButton({
    super.key,
    this.compact = false,
    this.color,
    this.iconSize = 16,
  });

  @override
  State<AppUpdateButton> createState() => _AppUpdateButtonState();
}

class _AppUpdateButtonState extends State<AppUpdateButton>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _performCheck() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);
    _animController.repeat();

    try {
      await AutoUpdateManager.instance.performManualCheck(context);
    } catch (e) {
      if (mounted) {
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
                  child: Text(
                    'An unexpected error occurred: $e',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        _animController.stop();
        _animController.reset();
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 520;
    final showFullText = !widget.compact && !isNarrow;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Tooltip(
          message: 'Check for updates (Current: v${AppConfig.currentVersion})',
          child: ClickableCursor(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isChecking ? null : _performCheck,
                hoverColor: Colors.white.withOpacity(0.18),
                splashColor: Colors.white.withOpacity(0.24),
                child: Container(
                  height: 36,
                  padding: EdgeInsets.symmetric(
                    horizontal: showFullText ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildIcon(),
                      if (showFullText) ...[
                        const SizedBox(width: 8),
                        Text(
                          _isChecking ? 'Checking...' : 'Check for Updates',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ] else if (screenWidth >= 380) ...[
                        const SizedBox(width: 6),
                        Text(
                          _isChecking ? '...' : 'Updates',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (_isChecking) {
      return RotationTransition(
        turns: _animController,
        child: Icon(
          Icons.sync_rounded,
          color: Colors.white,
          size: widget.iconSize,
        ),
      );
    }

    return Icon(
      Icons.system_update_alt_rounded,
      color: widget.color ?? Colors.white,
      size: widget.iconSize,
    );
  }
}
