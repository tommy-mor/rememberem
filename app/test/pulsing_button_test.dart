import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/memories/pulsing_button.dart';
import 'package:rememberem_core/rememberem_core.dart';

void main() {
  final theme = RememberemTheme.light(const AppSettings());
  final tinted = Color.alphaBlend(
    RememberemTheme.gold.withValues(alpha: PulsingButton.tint),
    RememberemTheme.raised(theme),
  );

  Future<void> show(
    WidgetTester tester, {
    bool visible = true,
    bool still = false,
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: still,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: visible
            ? PulsingButton(label: '+ date', onPressed: () {})
            : const SizedBox(),
      ),
    ),
  );

  /// Frames every 100 ms, as a running app has, for [ms].
  Future<void> run(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Color? background(WidgetTester tester) => tester
      .widget<FilledButton>(find.byType(FilledButton))
      .style
      ?.backgroundColor
      ?.resolve({});

  testWidgets('it pulses, then settles after three cycles, still tinted', (
    tester,
  ) async {
    await show(tester);
    expect(background(tester), tinted);

    await tester.pump(const Duration(milliseconds: 450));
    expect(background(tester), isNot(tinted));

    // Settling at all means it stopped; a pulse for ever would time out.
    await tester.pumpAndSettle();
    expect(background(tester), tinted);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('it runs three cycles of 1.8 seconds, not two or four', (
    tester,
  ) async {
    await show(tester);
    // Each cycle is down and up, 900 ms each way.
    await run(tester, 5200);
    expect(tester.hasRunningAnimations, isTrue);
    await run(tester, 1400);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('collapsing and opening it again restarts the pulse', (
    tester,
  ) async {
    await show(tester);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await show(tester, visible: false);
    await show(tester);
    await tester.pump(const Duration(milliseconds: 450));

    expect(tester.hasRunningAnimations, isTrue);
    expect(background(tester), isNot(tinted));
    await tester.pumpAndSettle();
    expect(background(tester), tinted);
  });

  testWidgets('a change of MediaQuery after the three cycles does not '
      'restart it', (tester) async {
    await show(tester);
    await tester.pumpAndSettle();

    await show(tester, scale: 1.5);
    await tester.pump(const Duration(milliseconds: 450));
    await show(tester, scale: 2);
    await tester.pump(const Duration(milliseconds: 450));

    expect(tester.hasRunningAnimations, isFalse);
    expect(background(tester), tinted);
  });

  testWidgets('a change of MediaQuery during the cycles does not restart '
      'them either', (tester) async {
    await show(tester);
    await run(tester, 4500);
    await show(tester, scale: 2);
    await run(tester, 2500);

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with less motion asked for it shows the full tint at once', (
    tester,
  ) async {
    await show(tester, still: true);
    expect(background(tester), tinted);

    await tester.pump(const Duration(milliseconds: 450));
    expect(background(tester), tinted);
    await tester.pumpAndSettle();
    expect(background(tester), tinted);
  });
}
