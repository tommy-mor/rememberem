import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/detail_finders.dart';
import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  late Memory memory;

  Future<void> showCard(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryEditScreen(
          memory: memory,
          services: testServices(repository, dictation: FakeDictation()),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    repository = FakeMemoryRepository();
    memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
    );
  });

  testWidgets('with every section empty, each header, its count and its add '
      'button still show', (tester) async {
    await showCard(tester);

    for (final kind in DetailKind.values) {
      expect(
        find.text('${kind.plural.toUpperCase()}  0'),
        findsOneWidget,
        reason: kind.plural,
      );
      expect(addDetailButton(kind), findsOneWidget, reason: kind.plural);
    }
    expect(find.widgetWithText(TextField, 'NAME'), findsOneWidget);
  });

  group('the Undo bar and the Undo snack bars', () {
    /// A fact written and deleted, which leaves a "Detail deleted" snack
    /// bar up.
    Future<void> deleteAFact(WidgetTester tester) async {
      memory = memory.withDetails([
        Detail(id: 'f', text: 'Tall', at: DateTime(2026)),
      ]);
      await repository.save(memory);
      await showCard(tester);
      await tester.tap(openToggle('Fact'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete Fact'));
      await tester.pumpAndSettle(); // in, and its timer started
      expect(find.text('Detail deleted'), findsOneWidget);
    }

    Finder bar() => find.byTooltip('Undo');

    testWidgets('the snack bar lasts ten seconds', (tester) async {
      await deleteAFact(tester);

      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Detail deleted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Detail deleted'), findsNothing);
    });

    testWidgets('the bar\'s Undo is tappable while a snack bar shows', (
      tester,
    ) async {
      await deleteAFact(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Detail deleted'), findsOneWidget);
      expect(bar().hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.undo_rounded),
            )
            .onPressed,
        isNotNull,
      );
      // The snack bar sits above the bar, not over it.
      final snack = tester.getRect(find.byType(SnackBar));
      expect(snack.bottom, lessThanOrEqualTo(tester.getRect(bar()).top));
      await tester.tap(bar());
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.redo_rounded),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('the bar\'s Undo is tappable after the snack bar has gone', (
      tester,
    ) async {
      await deleteAFact(tester);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(find.text('Detail deleted'), findsNothing);
      expect(bar().hitTestable(), findsOneWidget);
      await tester.tap(bar());
      await tester.pumpAndSettle();
    });

    testWidgets('the bar\'s Undo is tappable with the keyboard up', (
      tester,
    ) async {
      await deleteAFact(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Detail deleted'), findsOneWidget);
      expect(bar().hitTestable(), findsOneWidget);
      // On the keyboard, not under it.
      expect(tester.getRect(bar()).bottom, lessThanOrEqualTo(800 - 300));
      await tester.tap(bar());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
