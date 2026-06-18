import 'package:flutter/material.dart';

class CafeColors {
  static const Color flame = Color(0xFF534AB7);
  static const Color espresso = Color(0xFF111118);
  static const Color steam = Color(0xFFFFFFFF);
  static const Color creme = Color(0xFFEEEDFE);
  static const Color olive = Color(0xFF1D9E75);
  static const Color oliveLight = Color(0xFFE1F5EE);
  static const Color charcoal = Color(0xFF111118);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF534AB7), // NovaColors.violet
      Color(0xFF3C3489), // NovaColors.violetDeep
      Color(0xFF085041), // NovaColors.tealDeep
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
