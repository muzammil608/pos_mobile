import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF534AB7);
  static const Color secondary = Color(0xFF1D9E75);
  static const Color surface = Color(0x66FFFFFF);
  static const Color textPrimary = Color(0xFF171717);
  static const Color accent = Color(0xFF1E1E1E);
  static const Color softBackground = Color(0xFFF2F2F2);
  static const Color danger = Color(0xFFD32F2F);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: Colors.white,
    focusColor: Colors.transparent,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF111118),
    ),
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: textPrimary,
      onSurface: textPrimary,
      error: danger,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111118),
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 8,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black45,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary.withOpacity(0.18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xE6FFFFFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: textPrimary.withOpacity(0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Color(0xFF534AB7),
      selectionColor: Color(0x33534AB7),
      selectionHandleColor: Color(0xFF534AB7),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[400],
        disabledForegroundColor: Colors.grey[700],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom().copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom().copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom().copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),
    ),
    listTileTheme: ListTileThemeData(
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
    ),
    checkboxTheme: CheckboxThemeData(
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
    ),
    radioTheme: RadioThemeData(
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
    ),
    switchTheme: SwitchThemeData(
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: primary.withOpacity(0.18),
      selectedColor: primary,
      secondarySelectedColor: textPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textPrimary),
    ),
  );
}
