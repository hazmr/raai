import 'package:flutter/material.dart';

/// The entire design system (FLUTTER_APP_DESIGN.md §1.1). Keep it this small:
/// one accent color, one font, a 5-step spacing scale. If a screen needs more, cut it.
class AppTokens {
  // Spacing — nothing outside this scale.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;

  // Radius
  static const double rTile = 16; // bento tiles
  static const double rControl = 12; // buttons / inputs

  // Touch target (field use, gloves)
  static const double touchTarget = 56;

  // Colors
  static const Color primary = Color(0xFF2E7D32); // pasture green
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF4F5F3); // warm neutral
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF5F6360);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB26A00);
  static const Color error = Color(0xFFC62828);

  static const String fontFamily = 'Cairo';
}

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppTokens.primary,
    surface: AppTokens.surface,
    error: AppTokens.error,
    onPrimary: Colors.white,
    onSurface: AppTokens.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppTokens.background,
    fontFamily: AppTokens.fontFamily,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTokens.textPrimary),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTokens.textPrimary),
      bodyLarge: const TextStyle(fontSize: 16, color: AppTokens.textPrimary),
      bodyMedium: const TextStyle(fontSize: 16, color: AppTokens.textPrimary),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      labelSmall: const TextStyle(fontSize: 13, color: AppTokens.textSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: AppTokens.s16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rControl),
        borderSide: const BorderSide(color: Color(0xFFD9DCD8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rControl),
        borderSide: const BorderSide(color: Color(0xFFD9DCD8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rControl),
        borderSide: const BorderSide(color: AppTokens.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppTokens.touchTarget),
        backgroundColor: AppTokens.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rControl)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
