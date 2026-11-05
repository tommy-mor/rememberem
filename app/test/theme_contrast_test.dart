import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem_core/rememberem_core.dart';

void main() {
  test('app bar text is readable (4.5:1) on every theme colour', () {
    for (final value in AppPalette.themeColors) {
      final bar = Color(value);
      final text = RememberemTheme.barText(bar);
      expect(
        RememberemTheme.contrast(text, bar),
        greaterThanOrEqualTo(4.5),
        reason: AppPalette.names[value],
      );
    }
  });

  test('gold stays where it can be read', () {
    expect(RememberemTheme.barText(RememberemTheme.navy), RememberemTheme.gold);
  });

  /// Every combination Fred can pick: each theme colour on each background
  /// (a light background makes the light theme, a dark one the dark theme).
  Iterable<(String, ThemeData)> allThemes() sync* {
    for (final colour in AppPalette.themeColors) {
      for (final background in AppPalette.backgrounds) {
        final settings = AppSettings(
          themeColor: colour,
          backgroundColor: background,
        );
        yield (
          '${AppPalette.names[colour]} on $background',
          AppPalette.isDark(background)
              ? RememberemTheme.dark(settings)
              : RememberemTheme.light(settings),
        );
      }
    }
  }

  test('the app bar suffix is readable (4.5:1) in every theme', () {
    for (final (name, theme) in allThemes()) {
      final bar = theme.appBarTheme.backgroundColor!;
      final suffix = RememberemTheme.suffixColor(
        theme.appBarTheme.foregroundColor!,
        bar,
      );
      expect(
        RememberemTheme.contrast(suffix, bar),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    }
  });

  test('the remembered green reads (3:1) on every background', () {
    for (final background in AppPalette.backgrounds) {
      expect(
        RememberemTheme.contrast(
          RememberemTheme.rememberedGreen,
          Color(background),
        ),
        greaterThanOrEqualTo(3),
        reason: '$background',
      );
    }
  });

  test('an unfocused ledger underline is visible (3:1)', () {
    for (final (name, theme) in allThemes()) {
      final decoration = RememberemTheme.ledgerDecoration(theme, label: 'x');
      final line = decoration.enabledBorder!.borderSide;
      final page = theme.colorScheme.surface;
      expect(
        RememberemTheme.contrast(Color.alphaBlend(line.color, page), page),
        greaterThanOrEqualTo(3),
        reason: name,
      );
      expect(line.width, 1.5);
      expect(decoration.focusedBorder!.borderSide.width, 2);
    }
  });

  test('the progress bar shows against its track and the page (3:1)', () {
    for (final (name, theme) in allThemes()) {
      final primary = theme.colorScheme.primary;
      final page = theme.colorScheme.surface;
      final track = Color.alphaBlend(primary.withValues(alpha: 0.16), page);
      expect(
        RememberemTheme.contrast(primary, track),
        greaterThanOrEqualTo(3),
        reason: '$name fill on track',
      );
      expect(
        RememberemTheme.contrast(primary, page),
        greaterThanOrEqualTo(3),
        reason: '$name outline on page',
      );
    }
  });

  test('snack bars: navy with gold action on light, raised on dark', () {
    final light = RememberemTheme.light(const AppSettings()).snackBarTheme;
    expect(light.behavior, SnackBarBehavior.fixed);
    expect(light.backgroundColor, RememberemTheme.deepNavy);
    expect(
      RememberemTheme.contrast(RememberemTheme.gold, RememberemTheme.deepNavy),
      greaterThanOrEqualTo(4.5),
    );
    final dark = RememberemTheme.dark(
      const AppSettings(backgroundColor: 0xFF1E2023),
    );
    expect(dark.snackBarTheme.behavior, SnackBarBehavior.fixed);
    expect(
      dark.snackBarTheme.backgroundColor,
      dark.colorScheme.surfaceContainerHigh,
    );
    expect(
      RememberemTheme.contrast(
        RememberemTheme.gold,
        dark.snackBarTheme.backgroundColor!,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('the countdown drain bar shows on its button (3:1)', () {
    for (final (name, theme) in allThemes()) {
      final scheme = theme.colorScheme;
      expect(
        RememberemTheme.contrast(scheme.primary, scheme.secondaryContainer),
        greaterThanOrEqualTo(3),
        reason: name,
      );
    }
  });

  test('the quiz progress bar shows on the app bar it sits on (3:1)', () {
    for (final (name, theme) in allThemes()) {
      final bar = theme.appBarTheme.backgroundColor!;
      expect(
        RememberemTheme.contrast(RememberemTheme.gold, bar),
        greaterThanOrEqualTo(3),
        reason: name,
      );
    }
  });

  test('the dark snack bar outline shows against its fill (3:1)', () {
    for (final (name, theme) in allThemes()) {
      if (theme.brightness != Brightness.dark) continue;
      final scheme = theme.colorScheme;
      expect(
        RememberemTheme.contrast(scheme.outline, scheme.surfaceContainerHigh),
        greaterThanOrEqualTo(3),
        reason: name,
      );
    }
  });
}
