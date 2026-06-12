import 'package:flutter/material.dart';
import '../theme/nova_theme.dart';

enum AppNoticeType { success, warning, error, info }

class AppNoticeHost extends StatefulWidget {
  final Widget child;

  const AppNoticeHost({super.key, required this.child});

  @override
  State<AppNoticeHost> createState() => AppNoticeHostState();

  static AppNoticeHostState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppNoticeHostState>();
}

class AppNoticeHostState extends State<AppNoticeHost> {
  final List<_ToastEntry> _toasts = [];

  void clear() {
    if (!mounted) return;
    setState(() => _toasts.clear());
  }

  void show(
    String message, {
    bool replaceOld = true,
    AppNoticeType type = AppNoticeType.info,
    Duration duration = const Duration(seconds: 2),
    String? subtitle,
    String? actionLabel,
  }) {
    if (replaceOld) _toasts.clear();

    final entry = _ToastEntry(
      id: UniqueKey(),
      message: message,
      subtitle: subtitle,
      actionLabel: actionLabel,
      type: type,
      duration: duration,
    );
    setState(() => _toasts.add(entry));
  }

  void _remove(Key id) {
    if (mounted) setState(() => _toasts.removeWhere((e) => e.id == id));
  }

  void showOrderSuccess({
    required String orderNo,
    required double total,
    required String paymentMethod,
    double change = 0,
  }) {
    final sub = paymentMethod == 'cash' && change > 0
        ? 'Rs ${total.toStringAsFixed(0)} · Cash · Change: Rs ${change.toStringAsFixed(0)}'
        : 'Rs ${total.toStringAsFixed(0)} · ${paymentMethod == 'cash' ? 'Cash' : 'Card'}';
    show(
      'Order #$orderNo placed',
      subtitle: sub,
      type: AppNoticeType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void showStockWarning(List<String> alerts) {
    final items = alerts.take(2).join(', ');
    final extra = alerts.length > 2 ? ' +${alerts.length - 2} more' : '';
    show(
      'Low stock warning',
      subtitle: '$items$extra',
      type: AppNoticeType.warning,
      duration: const Duration(seconds: 2),
    );
  }

  void showOutOfStock(String details) {
    show(
      'Cannot place order',
      subtitle: details,
      type: AppNoticeType.error,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_toasts.isNotEmpty)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _toasts
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _AppNoticeToast(
                            key: e.id,
                            entry: e,
                            onDismiss: () => _remove(e.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastEntry {
  final Key id;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final AppNoticeType type;
  final Duration duration;

  const _ToastEntry({
    required this.id,
    required this.message,
    this.subtitle,
    this.actionLabel,
    required this.type,
    required this.duration,
  });
}

class AppNotice {
  static void show(
    BuildContext context,
    String message, {
    AppNoticeType type = AppNoticeType.info,
    Duration duration = const Duration(seconds: 2),
    String? subtitle,
    String? actionLabel,
  }) {
    final host = AppNoticeHost.of(context);
    if (host != null) {
      host.show(
        message,
        type: type,
        duration: duration,
        subtitle: subtitle,
        actionLabel: actionLabel,
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static void showOrderSuccess(
    BuildContext context, {
    required String orderNo,
    required double total,
    required String paymentMethod,
    double change = 0,
  }) {
    final host = AppNoticeHost.of(context);
    if (host != null) {
      host.showOrderSuccess(
        orderNo: orderNo,
        total: total,
        paymentMethod: paymentMethod,
        change: change,
      );
      return;
    }
    final sub = paymentMethod == 'cash' && change > 0
        ? 'Rs ${total.toStringAsFixed(0)} · Cash · Change: Rs ${change.toStringAsFixed(0)}'
        : 'Rs ${total.toStringAsFixed(0)} · ${paymentMethod == 'cash' ? 'Cash' : 'Card'}';
    show(context, 'Order #$orderNo placed',
        subtitle: sub, type: AppNoticeType.success);
  }

  static void showStockWarning(BuildContext context, List<String> alerts) {
    final host = AppNoticeHost.of(context);
    if (host != null) {
      host.showStockWarning(alerts);
      return;
    }
    final items = alerts.take(2).join(', ');
    final extra = alerts.length > 2 ? ' +${alerts.length - 2} more' : '';
    show(context, 'Low stock warning',
        subtitle: '$items$extra', type: AppNoticeType.warning);
  }

  static void showOutOfStock(BuildContext context, String details) {
    final host = AppNoticeHost.of(context);
    if (host != null) {
      host.showOutOfStock(details);
      return;
    }
    show(context, 'Cannot place order',
        subtitle: details, type: AppNoticeType.error);
  }
}

class _AppNoticeToast extends StatefulWidget {
  final _ToastEntry entry;
  final VoidCallback onDismiss;

  const _AppNoticeToast({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  @override
  State<_AppNoticeToast> createState() => _AppNoticeToastState();
}

class _AppNoticeToastState extends State<_AppNoticeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    Future.delayed(widget.entry.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: _ToastCard(
            entry: widget.entry,
            onDismiss: _dismiss,
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  final _ToastEntry entry;
  final VoidCallback onDismiss;

  const _ToastCard({required this.entry, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = _schemeFor(entry.type);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: s.iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(s.icon, color: s.fg, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          entry.message,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: s.fg,
                            height: 1.25,
                          ),
                        ),
                        if (entry.subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            entry.subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: s.fgSub,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: s.iconBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.close_rounded, size: 13, color: s.fg),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NoticeScheme _schemeFor(AppNoticeType type) {
    switch (type) {
      case AppNoticeType.success:
        return const _NoticeScheme(
          bg: Color(0xFFEEFAF3),
          fg: Color(0xFF0F5132),
          fgSub: Color(0xFF1A7346),
          border: Color(0xFFABDFC4),
          iconBg: Color(0xFFCCF0DD),
          icon: Icons.check_circle_rounded,
          progressColor: Color(0xFF34C97A),
        );
      case AppNoticeType.warning:
        return const _NoticeScheme(
          bg: Color(0xFFFFFBEB),
          fg: Color(0xFF7A4100),
          fgSub: Color(0xFFA35A00),
          border: Color(0xFFFDD99B),
          iconBg: Color(0xFFFEEDC0),
          icon: Icons.warning_amber_rounded,
          progressColor: Color(0xFFF59E0B),
        );
      case AppNoticeType.error:
        return const _NoticeScheme(
          bg: Color(0xFFFFF0F0),
          fg: Color(0xFF7F1D1D),
          fgSub: Color(0xFFB91C1C),
          border: Color(0xFFFCA5A5),
          iconBg: Color(0xFFFECACA),
          icon: Icons.error_rounded,
          progressColor: Color(0xFFEF4444),
        );
      case AppNoticeType.info:
        return const _NoticeScheme(
          bg: NovaColors.bgPrimary,
          fg: NovaColors.textPrimary,
          fgSub: NovaColors.textSecondary,
          border: NovaColors.borderSecondary,
          iconBg: NovaColors.violetLight,
          icon: Icons.info_rounded,
          progressColor: NovaColors.violet,
        );
    }
  }
}

class _ProgressBar extends StatefulWidget {
  final Duration duration;
  final Color color;

  const _ProgressBar({required this.duration, required this.color});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => LinearProgressIndicator(
        value: 1.0 - _ctrl.value,
        minHeight: 3,
        backgroundColor: widget.color.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation(widget.color),
      ),
    );
  }
}

class _NoticeScheme {
  const _NoticeScheme({
    required this.bg,
    required this.fg,
    required this.fgSub,
    required this.border,
    required this.iconBg,
    required this.icon,
    required this.progressColor,
  });

  final Color bg;
  final Color fg;
  final Color fgSub;
  final Color border;
  final Color iconBg;
  final IconData icon;
  final Color progressColor;
}
