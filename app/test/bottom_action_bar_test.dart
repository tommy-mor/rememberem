import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/bottom_action_bar.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';

void main() {
  testWidgets('the bar keeps its buttons clear of a cutout at either side', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            viewPadding: EdgeInsets.only(left: 40, right: 48),
          ),
          child: Scaffold(
            bottomNavigationBar: BottomActionBar(
              start: TextButton(onPressed: () {}, child: const Text('Reset')),
              end: FilledButton(onPressed: () {}, child: const Text('Done')),
            ),
          ),
        ),
      ),
    );

    final end = tester.getRect(find.byType(FilledButton));
    final start = tester.getRect(find.byType(TextButton));
    expect(end.right, lessThanOrEqualTo(800 - 48 - RememberemTheme.gutter));
    expect(start.left, greaterThanOrEqualTo(40 + RememberemTheme.gutter));
  });
}
