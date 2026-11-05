import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/speech/dictated_text_field.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    bool showMic = true,
    String? hint,
    VisualDensity? density,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: RememberemTheme.light(const AppSettings())
          .copyWith(visualDensity: density),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: DictatedTextField(
            ledger: true,
            label: 'Place',
            hint: hint,
            initialValue: 'Home',
            dictation: FakeDictation(),
            onChanged: (_) {},
            showMic: showMic,
            dense: true,
          ),
        ),
      ),
    ),
  );

  testWidgets('the mic is at least 48 x 48, even at compact density', (
    tester,
  ) async {
    await show(tester, density: VisualDensity.compact);
    final size = tester.getSize(find.byTooltip('Speak Place'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a ledger field is at least 48 dp tall, with or without the '
      'mic, at compact density and with large text', (tester) async {
    for (final showMic in [true, false]) {
      for (final scale in [1.0, 2.0]) {
        await show(
          tester,
          showMic: showMic,
          density: VisualDensity.compact,
          scale: scale,
        );
        final field = find.byType(TextField);
        expect(
          tester.getSize(field).height,
          greaterThanOrEqualTo(48),
          reason: 'mic $showMic, scale $scale',
        );
      }
    }
  });

  testWidgets('the label is an overline over an underline, not a box', (
    tester,
  ) async {
    await show(tester, hint: 'unknown');
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.label, isNotNull);
    expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(decoration.enabledBorder, isA<UnderlineInputBorder>());
    expect(decoration.border, isNot(isA<OutlineInputBorder>()));
    expect(find.text('PLACE'), findsOneWidget);
    // A screen reader gets the label as written, not spelled-out capitals.
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel('Place'), findsOneWidget);
    expect(find.bySemanticsLabel('PLACE'), findsNothing);
    handle.dispose();
  });

  testWidgets('without the mic there is no button, and the hint shows at '
      'once on an empty field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RememberemTheme.light(const AppSettings()),
        home: Scaffold(
          body: DictatedTextField(
            ledger: true,
            label: 'Place',
            hint: 'unknown',
            initialValue: '',
            dictation: FakeDictation(),
            onChanged: (_) {},
            showMic: false,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Speak Place'), findsNothing);
    expect(find.text('unknown'), findsOneWidget);
  });

  testWidgets(
    'without ledger there is no explicit box (screens not yet moved keep the theme default)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DictatedTextField(
              label: 'Place',
              initialValue: '',
              dictation: FakeDictation(),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.labelText, 'Place');
      expect(decoration.border, isNull); // the theme's own, no explicit box
    },
  );
}
