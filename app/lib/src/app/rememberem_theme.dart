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

  /// Text fields' inner padding: 70 % of Material 3's outlined default
  /// (12, 20, 12, 12), for a tighter page.
  static const fieldPadding = EdgeInsets.fromLTRB(8.4, 14, 8.4, 8.4);

  /// The same for dense fields (Material's 12, 16, 12, 8), used in lists.
  static const denseFieldPadding = EdgeInsets.fromLTRB(8.4, 11.2, 8.4, 5.6);

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

  /// Dark pages from the theme colour, on the chosen dark background if
  /// there is one; a light background choice does not apply.
  static ThemeData dark(AppSettings settings) {
    final primary = Color(settings.themeColor);
    final chosen = AppPalette.isDark(settings.backgroundColor)
        ? Color(settings.backgroundColor)
        : null;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      secondary: gold,
      onSecondary: deepNavy,
      tertiary: gold,
      onTertiary: deepNavy,
      surface: chosen,
    );
    // On a chosen background the bar is a lighter shade of it, so the
    // two belong together.
    final bar = chosen == null
        ? scheme.surfaceContainerHighest
        : Color.alphaBlend(Colors.white.withAlpha(28), chosen);
    return _themed(scheme, bar, scheme.surface);
  }

  /// Gold on the app bar where it can be read (4.5:1, WCAG AA), else
  /// white, else deep navy.
  static Color barText(Color bar) {
    for (final text in const [gold, Colors.white]) {
      if (contrast(text, bar) >= 4.5) return text;
    }
    return deepNavy;
  }

  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
  }

  static ThemeData _themed(ColorScheme scheme, Color bar, Color background) =>
      _withBar(scheme, bar, background, barText(bar));

  static ThemeData _withBar(
    ColorScheme scheme,
    Color bar,
    Color background,
    Color text,
  ) => ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    inputDecorationTheme: const InputDecorationTheme(
      contentPadding: fieldPadding,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bar,
      foregroundColor: text,
      iconTheme: IconThemeData(color: text),
      actionsIconTheme: IconThemeData(color: text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: deepNavy,
    ),
    listTileTheme: ListTileThemeData(selectedColor: scheme.primary),
  );
}
