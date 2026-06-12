import 'package:flutter/material.dart';

class ResponsiveLayout {
  static const double desktopBreakpoint = 900;
  static const double wideBreakpoint = 1200;
  static const double maxContentWidth = 1280;

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= wideBreakpoint;
  }

  static double horizontalPadding(double width) {
    if (width >= 1400) return 32;
    if (width >= desktopBreakpoint) return 24;
    return 16;
  }

  static int productColumns(double width) {
    if (width >= 1500) return 7;
    if (width >= 1200) return 6;
    if (width >= 900) return 5;
    if (width >= 600) return 3;
    return 2;
  }

  static int cardColumns(double width) {
    if (width >= 1200) return 3;
    if (width >= desktopBreakpoint) return 2;
    return 1;
  }
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal =
            ResponsiveLayout.horizontalPadding(constraints.maxWidth);

        final boundedHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : null;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: boundedHeight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding:
                    padding ?? EdgeInsets.symmetric(horizontal: horizontal),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
