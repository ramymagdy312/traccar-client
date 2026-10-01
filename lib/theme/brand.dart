import 'package:flutter/material.dart';

/// SerbTracker identity, taken from the logo lockup: lime pin + charcoal ink.
abstract final class Brand {
  /// The pin in `assets/ic_SerbTracker.png`.
  static const Color green = Color(0xFF0AD200);

  /// The wheel and wordmark in the light lockup.
  static const Color ink = Color(0xFF11161A);

  /// The wheel and wordmark in the dark lockup.
  static const Color paper = Color(0xFFEDF1F1);

  /// Semantic colours for a trip's lifecycle. Kept separate from [Brand]
  /// so the lime identity never collides with "pending / active / done".
  static const Color statusPending = Color(0xFF0D7377);
  static const Color statusPendingAlt = Color(0xFF14A3A8);
  static const Color statusPendingDark = Color(0xFF4DD0E1);
  static const Color statusPendingContainer = Color(0xFFD4F1F2);
  static const Color statusPendingContainerDark = Color(0xFF0E2F31);
  static const Color statusPendingOnContainer = Color(0xFF083E40);
  static const Color statusPendingOnContainerDark = Color(0xFFB8F0F2);

  static const Color statusActive = Color(0xFFC62828);
  static const Color statusActiveAlt = Color(0xFFE57373);
  static const Color statusActiveDark = Color(0xFFE57373);
  static const Color statusActiveAltDark = Color(0xFFFF8A65);

  static const Color statusDone = Color(0xFF2E7D32);
  static const Color statusDoneAlt = Color(0xFF43A047);
  static const Color statusDoneDark = Color(0xFF66BB6A);
  static const Color statusDoneContainer = Color(0xFFE8F5E9);
  static const Color statusDoneContainerDark = Color(0xFF16361C);
  static const Color statusDoneOnContainer = Color(0xFF1B5E20);
  static const Color statusDoneOnContainerDark = Color(0xFFB7F0C2);

  static const Color _surfaceLight = Color(0xFFF4FBF3);
  static const Color _surfaceDark = Color(0xFF11161A);
  static const Color _outlineLight = Color(0xFFD5E5D0);
  static const Color _outlineDark = Color(0xFF3A4338);

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: green,
      onPrimary: ink,
      secondary: ink,
      onSecondary: paper,
      surface: _surfaceLight,
      onSurface: ink,
    ),
    outline: _outlineLight,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: green,
      onPrimary: ink,
      secondary: paper,
      onSecondary: ink,
      surface: _surfaceDark,
      onSurface: paper,
    ),
    outline: _outlineDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color outline,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: 8,
        height: 70,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
