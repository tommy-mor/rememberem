import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/detail_extras_editor.dart';
import 'package:rememberem/src/memories/detail_help_dialog.dart';
import 'package:rememberem/src/memories/detail_list_editor.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/speech/speech_transcript.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  group('SpeechTranscript', () {
    test('a growing result replaces the last one', () {
      final t = SpeechTranscript();
      t.add('my');
      t.add('my name');
      expect(t.add('my name is Ann'), 'my name is Ann');
    });

    test('a revised guess replaces, even when it changes later words', () {
      final t = SpeechTranscript();
      t.add('she has two dogs');
      expect(t.add('she has blue'), 'she has blue');
    });

    test('a recogniser starting over after a pause keeps what came before', () {
      final t = SpeechTranscript();
      t.add('she works at the');
      t.add('she works at the library');
      t.add('and');
      expect(t.add('and has a cat'), 'she works at the library and has a cat');
    });

    test('a new stretch with the same first word is kept', () {
      final t = SpeechTranscript();
      t.add('she works at the library');
      expect(
        t.add('she has a cat'),
        'she works at the library she has a cat',
      );
    });

    test('a new stretch is kept even when it is as long as the last', () {
      final t = SpeechTranscript();
      t.add('hi');
      expect(t.add('hello there'), 'hi hello there');
      final u = SpeechTranscript();
      u.add('I');
      expect(u.add("I'm going"), "I'm going"); // grew from its start
    });

    test('after a final result, the next one is a new stretch', () {
      final t = SpeechTranscript();
      t.add('hello', isFinal: true);
      t.add('hello', isFinal: true); // sent twice
      expect(t.add('hello again'), 'hello hello again');
    });

    test('an empty result changes nothing', () {
      final t = SpeechTranscript();
      t.add('tall', isFinal: true);
      expect(t.add(''), 'tall');
      expect(t.add('and kind'), 'tall and kind');
    });
  });

  group('person card details', () {
    late FakeMemoryRepository repository;
    late Memory memory;

    Future<void> showCard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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

    Future<void> add(WidgetTester tester, String kind) async {
      await tester.ensureVisible(find.text('+ $kind'));
      await tester.tap(find.text('+ $kind'));
      await tester.pumpAndSettle();
    }

    Memory saved() => repository.stored[memory.id]!;

    setUp(() async {
      repository = FakeMemoryRepository();
      memory = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 11, 1),
      );
    });

    testWidgets('a tag made on this card is offered for the next tag', (
      tester,
    ) async {
      await showCard(tester);
      await add(tester, 'tag');
      await tester.enterText(
        find.widgetWithText(TextField, 'Create a tag'),
        'Choir',
      );
      await tester.pumpAndSettle();
      // Close the first tag, then add another.
      await tester.tapAt(
        tester.getCenter(find.widgetWithText(TextField, 'Name')),
      );
      await tester.pumpAndSettle();

      await add(tester, 'tag');
      expect(find.widgetWithText(ChoiceChip, 'Choir'), findsOneWidget);
      expect(find.text(DetailExtrasEditor.noTagsYet), findsNothing);
      expect(find.text(DetailExtrasEditor.keepTagsKind), findsNothing);
      // "+ place" and "+ date" sit side by side.
      expect(
        tester.getTopLeft(find.text('+ place').last).dy,
        tester.getTopLeft(find.text('+ date').last).dy,
      );
    });

    testWidgets('a tag without a type or words warns, and is not kept', (
      tester,
    ) async {
      await showCard(tester);
      await add(tester, 'tag');
      expect(find.text(DetailExtrasEditor.needsType), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      expect(saved().details, isEmpty);
    });

    testWidgets('each open detail has a "?" that explains its kind', (
      tester,
    ) async {
      await showCard(tester);
      await add(tester, 'anniversary');

      await tester.tap(find.byTooltip('About anniversary details'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailHelpDialog), findsOneWidget);
      expect(
        find.text(DetailHelpDialog.textFor(DetailKind.anniversary).first),
        findsOneWidget,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailHelpDialog), findsNothing);
    });

    testWidgets('a later visit has no mics until a detail is opened', (
      tester,
    ) async {
      memory = memory.withDetails([
        Detail(id: 'f', text: 'Tall', at: DateTime(2026)),
      ]);
      await repository.save(memory);
      await showCard(tester);
      expect(find.byIcon(Icons.mic), findsNothing);

      await tester.tap(find.byTooltip('Open Fact'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Speak Fact'), findsOneWidget);
    });

    testWidgets('someone just met has mics on Name, Place and Meeting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryEditScreen(
            memory: memory,
            justMet: true,
            services: testServices(repository, dictation: FakeDictation()),
          ),
        ),
      );
      await tester.pump();
      for (final label in ['Name', 'Place', 'Meeting']) {
        expect(find.byTooltip('Speak $label'), findsOneWidget);
      }
    });
  });

  test('every kind has help', () {
    for (final kind in DetailKind.values) {
      expect(DetailHelpDialog.textFor(kind), isNotEmpty);
    }
  });

  test('an anniversary and a relationship show their data before the text, '
      'not on the border', () {
    String? names(String id) => id == 'j' ? 'Jill' : null;
    final wedding = Detail(
      id: 'a',
      text: '',
      at: DateTime.utc(2026),
      type: DetailKind.anniversary,
      label: 'wedding',
      eventDate: DateTime(2010, 6, 3),
    );
    expect(DetailListEditor.rowLabel(wedding), 'Anniversary');
    expect(
      DetailListEditor.fieldPrefix(wedding, names),
      'Wedding: 3 Jun 2010 - ',
    );
    final boss = Detail(
      id: 'r',
      text: '',
      at: DateTime.utc(2026),
      type: DetailKind.relationship,
      label: 'boss',
      targetId: 'j',
    );
    expect(DetailListEditor.rowLabel(boss), 'Relationship');
    expect(DetailListEditor.fieldPrefix(boss, names), 'Boss: Jill - ');
    expect(
      DetailListEditor.fieldPrefix(boss.copyWith(label: ''), names),
      'Jill - ',
    );
    final picnic = Detail(
      id: 'h',
      text: '',
      at: DateTime(2026, 5, 3, 10),
      type: DetailKind.happening,
      place: 'Park',
    );
    expect(DetailListEditor.rowLabel(picnic), 'Happening · 3 May 2026 · Park');
    expect(DetailListEditor.fieldPrefix(picnic, names), isNull);
  });
}
