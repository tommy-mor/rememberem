import 'package:flutter/material.dart';

/// Navy and brushed gold, from the elephant logo.
class RememberemTheme {
  const RememberemTheme._();

  static const navy = Color(0xFF0A2A7A);
  static const deepNavy = Color(0xFF001952);
  static const gold = Color(0xFFE4BC52);
  static const paleGold = Color(0xFFFFF3D6);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: deepNavy,
      tertiary: gold,
      onTertiary: deepNavy,
      secondaryContainer: paleGold,
      onSecondaryContainer: deepNavy,
    );
    return ThemeData(
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: gold,
        iconTheme: IconThemeData(color: gold),
        actionsIconTheme: IconThemeData(color: gold),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: deepNavy,
      ),
      listTileTheme: const ListTileThemeData(selectedColor: navy),
    );
  }
}
