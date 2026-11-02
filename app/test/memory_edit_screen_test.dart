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
}
