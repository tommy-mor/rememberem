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

  /// The green of a remembered face's check. At least 3:1 on every
  /// background (`theme_contrast_test`).
  static const rememberedGreen = Color(0xFF228543);

  /// The one left and right margin on every screen.
  static const gutter = 16.0;

  /// The 4:5 portrait in a list row, and the smallest and largest sizes.
  static const thumbSmall = Size(24, 30);
  static const thumbRow = Size(38, 48);
  static const thumbTimeline = Size(44, 55);
  static const thumbCard = Size(136, 170);

  /// A row's gap between its photo and its text.
  static const thumbGap = 12.0;

  /// Where a row's text starts: gutter, photo, gap.
  static const rowTextInset = gutter + 38 + thumbGap;

  /// The smallest a tappable thing is, high and wide.
  static const tapTarget = 48.0;

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

  /// [on], a shade darker on a light page or lighter on a dark one, as
  /// cards sit on the page.
  static Color shade(ThemeData theme, Color on) => Color.alphaBlend(
    (theme.brightness == Brightness.dark ? Colors.white : Colors.black)
        .withAlpha(16),
    on,
  );

  /// An open card's fill: a lighter shade of the page, so it rises off it.
  static Color raised(ThemeData theme) {
    final page = theme.scaffoldBackgroundColor;
    return theme.brightness == Brightness.dark
        ? shade(theme, page)
        : Color.alphaBlend(Colors.white.withAlpha(140), page);
  }

  /// A section header's, field label's, or other overline: 12 sp, bold,
  /// spaced, for the caller to put in capitals.
  static TextStyle overline(ThemeData theme, {Color? color}) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    color: color ?? theme.colorScheme.onSurfaceVariant,
  );

  /// A hairline between rows: 8 % of the text colour.
  static Color rule(ThemeData theme) =>
      theme.colorScheme.onSurface.withValues(alpha: 0.08);

  /// The bar's muted suffix colour: its foreground at 75 %, or the least
  /// more that reads (4.5:1) on [bar].
  static Color suffixColor(Color foreground, Color bar) {
    for (final alpha in const [0.75, 0.8, 0.85, 0.9]) {
      final muted = Color.alphaBlend(foreground.withValues(alpha: alpha), bar);
      if (contrast(muted, bar) >= 4.5) return muted;
    }
    return foreground;
  }

  /// An app bar title with a muted [suffix] after it ("Trash  3").
  static Widget titleWithSuffix(
    BuildContext context,
    String title,
    String suffix,
  ) {
    final bar = Theme.of(context).appBarTheme;
    final scheme = Theme.of(context).colorScheme;
    final foreground = bar.foregroundColor ?? scheme.onSurface;
    final background = bar.backgroundColor ?? scheme.surface;
    return Text.rich(
      TextSpan(
        text: title,
        children: [
          TextSpan(
            text: '  $suffix',
            style: TextStyle(color: suffixColor(foreground, background)),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// A ledger field's look: the label sits above the text as an overline
  /// and an underline replaces the box. Unfocused the underline is the text
  /// colour at 60 % (3:1 on every background); focused it is the theme
  /// colour, a little thicker. At least 48 dp tall.
  static InputDecoration ledgerDecoration(
    ThemeData theme, {
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    final scheme = theme.colorScheme;
    return InputDecoration(
      // Upper case to look at, the original case to a screen reader, which
      // would otherwise spell out the capitals.
      label: Semantics(
        label: label,
        excludeSemantics: true,
        child: Text(label.toUpperCase()),
      ),
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => overline(
          theme,
          color: states.contains(WidgetState.focused) ? scheme.primary : null,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      constraints: const BoxConstraints(minHeight: tapTarget),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      border: const UnderlineInputBorder(),
      suffixIcon: suffix,
    );
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
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: fieldPadding,
      // A placeholder reads as one: italic and faint, but still legible
      // (4.5:1 on the tinted cards).
      hintStyle: TextStyle(
        fontStyle: FontStyle.italic,
        color: scheme.onSurface.withAlpha(180),
      ),
    ),
    appBarTheme: AppBarTheme(
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: text,
      ),
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
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: 24,
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    snackBarTheme: _snackBar(scheme),
  );

  /// Navy with gold action text on light pages; a raised, outlined surface
  /// on dark ones. Fixed, so it sits above a bottom bar.
  static SnackBarThemeData _snackBar(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return SnackBarThemeData(
      behavior: SnackBarBehavior.fixed,
      backgroundColor: dark ? scheme.surfaceContainerHigh : deepNavy,
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: dark ? scheme.onSurface : Colors.white,
      ),
      actionTextColor: gold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: dark ? BorderSide(color: scheme.outline) : BorderSide.none,
      ),
    );
  }
}
