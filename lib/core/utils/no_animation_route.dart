import 'package:flutter/material.dart';

class NoAnimationPageRoute<T> extends PageRouteBuilder<T> {
  NoAnimationPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return builder(context);
          },
        );
}
