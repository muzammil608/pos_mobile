import 'package:flutter/material.dart';

class ClickableCursor extends StatelessWidget {
  const ClickableCursor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: child,
    );
  }
}
