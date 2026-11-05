import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/pill_button.dart';

void main() {
  testWidgets('a pill exposes a tap action to a screen reader, and it works', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PillButton(label: 'Filter', onPressed: () => presses++),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Filter'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.flagsCollection.isButton, isTrue);

    tester.semantics.tap(find.semantics.byLabel('Filter'));
    await tester.pump();
    expect(presses, 1);
    handle.dispose();
  });

  testWidgets('a pill with no handler is only a look', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PillButton(label: 'Sort')),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Sort'), findsOneWidget);
    handle.dispose();
  });
}
