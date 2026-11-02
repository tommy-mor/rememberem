import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

void main() {
  late FakeMemoryRepository repository;
  late FakeDictation dictation;
  late Memory memory;

  Future<void> showScreen(WidgetTester tester) async {
    // A phone-sized screen, so every field is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryEditScreen(
          memory: memory,
          repository: repository,
          dictation: dictation,
        ),
      ),
    );
  }

  Future<void> speakInto(
    WidgetTester tester,
    String label,
    String words,
  ) async {
    await tester.tap(find.byTooltip('Speak $label'));
    await tester.pump();
    dictation.say(words);
    dictation.goQuiet();
    await tester.pump();
  }

  setUp(() async {
    repository = FakeMemoryRepository();
    dictation = FakeDictation();
    memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
      location: const GeoPoint(47.61, -122.33),
    );
  });

  testWidgets('shows empty Name, Place, Meeting and Detail fields', (
    tester,
  ) async {
    await showScreen(tester);

    for (final label in ['Name', 'Place', 'Meeting', 'Detail']) {
      expect(find.widgetWithText(TextField, label), findsOneWidget);
      expect(find.byTooltip('Speak $label'), findsOneWidget);
    }
    expect(find.textContaining('47.61000, -122.33000'), findsOneWidget);
  });

  testWidgets('Fred speaks into each field and it all saves by itself', (
    tester,
  ) async {
    await showScreen(tester);

    await speakInto(tester, 'Name', 'Alex Davis');
    await speakInto(tester, 'Place', 'Stake Center');
    await speakInto(tester, 'Meeting', 'Sunday Meetings');
    await speakInto(
      tester,
      'Detail',
      'Alex is from Seattle and wants to sing in the choir.',
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Alex Davis'), findsOneWidget);
    final saved = repository.stored[memory.id]!;
    expect(saved.fields, {
      'name': 'Alex Davis',
      'place': 'Stake Center',
      'meeting': 'Sunday Meetings',
    });
    expect(saved.details.map((d) => d.text), [
      'Alex is from Seattle and wants to sing in the choir.',
    ]);
  });

  testWidgets('words appear while still being spoken', (tester) async {
    await showScreen(tester);

    await tester.tap(find.byTooltip('Speak Name'));
    await tester.pump();
    dictation.say('Alex');
    await tester.pump();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.byTooltip('Stop listening'), findsOneWidget);
  });

  testWidgets('dictation adds to text already typed', (tester) async {
    await showScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Detail'), 'Tall.');
    await speakInto(tester, 'Detail', 'Likes hiking.');

    expect(find.text('Tall. Likes hiking.'), findsOneWidget);
  });

  testWidgets('leaving the screen saves a change straight away', (
    tester,
  ) async {
    await showScreen(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Alex');

    await tester.pumpWidget(const SizedBox());

    expect(repository.stored[memory.id]!.field(MemoryField.name), 'Alex');
  });

  testWidgets('explains when speech recognition is unavailable', (
    tester,
  ) async {
    dictation = FakeDictation(available: false);
    await showScreen(tester);

    await tester.tap(find.byTooltip('Speak Name'));
    await tester.pump();

    expect(
      find.textContaining('Speech recognition is not available'),
      findsOneWidget,
    );
    expect(find.byTooltip('Speak Name'), findsOneWidget);
  });

  testWidgets('Add detail gives another box; both save in order', (
    tester,
  ) async {
    await showScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Detail'),
      'From Seattle',
    );
    await tester.tap(find.text('Add detail'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Detail 2'),
      'Sings in the choir',
    );
    await tester.tap(find.text('Add detail'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    expect(repository.stored[memory.id]!.details.map((d) => d.text), [
      'From Seattle',
      'Sings in the choir',
    ]);
  });

  testWidgets('adding a box mid-dictation keeps the words in the first box', (
    tester,
  ) async {
    await showScreen(tester);

    await tester.tap(find.byTooltip('Speak Detail'));
    await tester.pump();
    dictation.say('From');
    await tester.pump();
    final firstTime = repository.stored[memory.id]!.details.single.at;
    await tester.tap(find.text('Add detail'));
    await tester.pump();
    dictation.say('From Seattle');
    dictation.goQuiet();
    await tester.pump(const Duration(seconds: 1));

    final details = repository.stored[memory.id]!.details;
    expect(details.single.text, 'From Seattle');
    expect(details.single.at, firstTime);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Detail 2'))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('a legacy record shows its details and is not rewritten '
      'just by opening it', (tester) async {
    memory = Memory.fromJson({
      'id': 'old',
      'photo': 'old.jpg',
      'capturedAt': '2026-10-01T09:00:00.000Z',
      'fields': {'name': 'Alex', 'details': 'Likes hiking'},
    });
    await showScreen(tester);

    expect(find.text('Likes hiking'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    expect(repository.saves, isEmpty);
  });

  group('person card details', () {
    Future<void> showWithDetails(WidgetTester tester) async {
      memory = memory.withDetails([
        Detail(id: 'a', text: 'From Seattle', at: DateTime(2026, 11, 1, 10)),
        Detail(id: 'b', text: 'Sings', at: DateTime(2026, 11, 1, 11, 30)),
      ]);
      await showScreen(tester);
    }

    testWidgets('each saved detail shows its local recorded time', (
      tester,
    ) async {
      await showWithDetails(tester);

      expect(find.text('Sunday, November 1, 2026, 10:00 AM'), findsOneWidget);
      expect(find.text('Sunday, November 1, 2026, 11:30 AM'), findsOneWidget);
      expect(find.byTooltip('Delete Detail 3'), findsOneWidget);
      expect(find.textContaining('2026, '), findsNWidgets(2));
    });

    testWidgets('long-press the time to pick a new date and time', (
      tester,
    ) async {
      await showWithDetails(tester);

      await tester.longPress(find.text('Sunday, November 1, 2026, 10:00 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Sunday, November 15, 2026, 10:00 AM'), findsOneWidget);
      final saved = repository.saves.last.details.first;
      expect(saved.at.isAtSameMomentAs(DateTime(2026, 11, 15, 10)), isTrue);
      expect(saved.text, 'From Seattle');
    });

    testWidgets('cancelling the date picker changes nothing', (tester) async {
      await showWithDetails(tester);

      await tester.longPress(find.text('Sunday, November 1, 2026, 10:00 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Sunday, November 1, 2026, 10:00 AM'), findsOneWidget);
      expect(repository.saves, isEmpty);
    });

    testWidgets('delete removes a detail at once; Undo puts it back', (
      tester,
    ) async {
      await showWithDetails(tester);

      await tester.tap(find.byTooltip('Delete Detail'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // snackbar slides in
      expect(find.text('From Seattle'), findsNothing);
      expect(repository.saves.last.details.map((d) => d.text), ['Sings']);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('From Seattle'), findsOneWidget);
      expect(repository.saves.last.details.map((d) => d.text), [
        'From Seattle',
        'Sings',
      ]);

      await tester.enterText(
        find.widgetWithText(TextField, 'From Seattle'),
        'From Tacoma',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(repository.saves.last.details.first.text, 'From Tacoma');
    });

    testWidgets('deleting the only detail leaves one blank box', (
      tester,
    ) async {
      memory = memory.withDetails([
        Detail(id: 'a', text: 'Tall', at: DateTime(2026, 11, 1)),
      ]);
      await showScreen(tester);

      await tester.tap(find.byTooltip('Delete Detail'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Detail'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Detail 2'), findsNothing);
      expect(repository.saves.last.details, isEmpty);
    });

    testWidgets('a late dictation result cannot revive a deleted detail', (
      tester,
    ) async {
      await showWithDetails(tester);

      await tester.tap(find.byTooltip('Speak Detail'));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete Detail'));
      await tester.pump();
      dictation.sayLate('late words');
      await tester.pump(const Duration(seconds: 1));

      expect(repository.saves.last.details.map((d) => d.text), ['Sings']);
    });
  });

  group('leaving the card after a delete', () {
    testWidgets('back clears the Undo snackbar and the delete sticks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      memory = memory.withDetails([
        Detail(id: 'a', text: 'Tall', at: DateTime(2026, 11, 1)),
        Detail(id: 'b', text: 'Kind', at: DateTime(2026, 11, 1)),
      ]);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('list')),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => MemoryEditScreen(
            memory: memory,
            repository: repository,
            dictation: dictation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete Detail'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(repository.stored[memory.id]!.details.map((d) => d.id), ['b']);
    });

    testWidgets('leaving without the back handler also clears it', (
      tester,
    ) async {
      memory = memory.withDetails([
        Detail(id: 'a', text: 'Tall', at: DateTime(2026, 11, 1)),
      ]);
      await showScreen(tester);
      await tester.tap(find.byTooltip('Delete Detail'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const MaterialApp(home: Text('elsewhere')));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsNothing);
      expect(repository.stored[memory.id]!.details, isEmpty);
    });

    testWidgets('deleting a blank row saves nothing', (tester) async {
      await showScreen(tester);
      await tester.tap(find.text('Add detail'));
      await tester.pump();

      await tester.tap(find.byTooltip('Delete Detail 2'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Detail 2'), findsNothing);
      expect(repository.saves, isEmpty);
    });
  });
}
