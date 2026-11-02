import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Brushed gold on Fred's theme colour (navy by default, from the elephant
/// logo), over his chosen background.
class RememberemTheme {
  const RememberemTheme._();

  static const navy = Color(0xFF0A2A7A);
  static const deepNavy = Color(0xFF001952);
  static const gold = Color(0xFFE4BC52);
  static const paleGold = Color(0xFFFFF3D6);

  static ThemeData light(AppSettings settings) {
    final primary = Color(settings.themeColor);
    final background = Color(settings.backgroundColor);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: deepNavy,
      tertiary: gold,
      onTertiary: deepNavy,
      secondaryContainer: paleGold,
      onSecondaryContainer: deepNavy,
      surface: background,
    );
    return _themed(scheme, primary, background);
  }

  /// Dark pages from the theme colour; the background choice does not
  /// apply.
  static ThemeData dark(AppSettings settings) {
    final primary = Color(settings.themeColor);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      secondary: gold,
      onSecondary: deepNavy,
      tertiary: gold,
      onTertiary: deepNavy,
    );
    return _themed(scheme, scheme.surfaceContainerHighest, scheme.surface);
  }

  static ThemeData _themed(ColorScheme scheme, Color bar, Color background) =>
      ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        appBarTheme: AppBarTheme(
          backgroundColor: bar,
          foregroundColor: gold,
          iconTheme: const IconThemeData(color: gold),
          actionsIconTheme: const IconThemeData(color: gold),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: gold,
          foregroundColor: deepNavy,
        ),
        listTileTheme: ListTileThemeData(selectedColor: scheme.primary),
      );
}
