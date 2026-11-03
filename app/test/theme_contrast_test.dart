import 'dart:ui';

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
}
