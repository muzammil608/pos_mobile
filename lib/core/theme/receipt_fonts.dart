import 'package:flutter/material.dart';

class NovaFonts {
  static const String monoPrimary = 'Roboto Mono';

  static const List<String> monoFallback = <String>[
    'Source Code Pro',
    'Courier New',
    'monospace',
  ];

  static const TextStyle monoBase = TextStyle(
    fontFamily: monoPrimary,
    fontFamilyFallback: monoFallback,
  );

  static TextStyle receipt({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return monoBase.copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle price({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return receipt(
      fontSize: fontSize ?? 12,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
    );
  }

  static TextStyle code({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return receipt(
      fontSize: fontSize ?? 11,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }
}
