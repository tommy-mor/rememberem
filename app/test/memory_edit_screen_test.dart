import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  late FakeDictation dictation;
  late Memory memory;

  Future<void> showScreen(WidgetTester tester, {GeoPoint? here}) async {
    // A phone-sized screen, so every field is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryEditScreen(
          memory: memory,
          services: testServices(
            repository,
            dictation: dictation,
            location: FakeLocation(here),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Memory saved() => repository.stored[memory.id]!;

  /// Opens the add screen for [kind], types [description], and leaves the
  /// rest to [fill] before saving.
  Future<void> addDetail(
    WidgetTester tester,
    String kind,
    String description, {
    Future<void> Function()? fill,
  }) async {
    await tester.ensureVisible(find.text('+ $kind'));
    await tester.tap(find.text('+ $kind'));
    await tester.pumpAndSettle();
    if (fill != null) await fill();
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      description,
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<Memory> named(String name) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, repository.stored.length + 1),
    );
    final withName = m.withField('name', name);
    await repository.save(withName);
    return withName;
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

  testWidgets('shows Name, Place and Meeting, and four add buttons with no '
      'empty detail', (tester) async {
    await showScreen(tester);

    for (final label in ['Name', 'Place', 'Meeting']) {
      expect(find.widgetWithText(TextField, label), findsOneWidget);
      expect(find.byTooltip('Speak $label'), findsOneWidget);
    }
    for (final kind in ['fact', 'happening', 'relationship', 'anniversary']) {
      expect(find.text('+ $kind'), findsOneWidget);
    }
    expect(find.widgetWithText(TextField, 'Description'), findsNothing);
    expect(find.textContaining('47.61000, -122.33000'), findsOneWidget);
  });

  testWidgets('Fred speaks into each field and it all saves by itself', (
    tester,
  ) async {
    await showScreen(tester);

    await speakInto(tester, 'Name', 'Alex Davis');
    await speakInto(tester, 'Place', 'Stake Center');
    await speakInto(tester, 'Meeting', 'Sunday Meetings');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Alex Davis'), findsOneWidget);
    expect(saved().field(MemoryField.name), 'Alex Davis');
    expect(saved().latest.place, 'Stake Center');
    expect(saved().latest.meeting, 'Sunday Meetings');
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

    await tester.enterText(find.widgetWithText(TextField, 'Meeting'), 'Choir');
    await speakInto(tester, 'Meeting', 'practice');

    expect(find.text('Choir practice'), findsOneWidget);
  });

  testWidgets('leaving the screen saves a change straight away', (
    tester,
  ) async {
    await showScreen(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Alex');

    await tester.pumpWidget(const SizedBox());

    expect(saved().field(MemoryField.name), 'Alex');
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

  testWidgets('a fact is just a description, spoken or typed', (tester) async {
    await showScreen(tester);

    await tester.tap(find.text('+ fact'));
    await tester.pumpAndSettle();
    await speakInto(tester, 'Description', 'Sings in the choir');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final fact = saved().details.single;
    expect(fact.kind, DetailKind.fact);
    expect(fact.text, 'Sings in the choir');
    expect(find.text('Fact'), findsOneWidget);
    expect(find.text('Sings in the choir'), findsOneWidget);
  });

  testWidgets('Save stays off until the description and the parts of the '
      'kind are given', (tester) async {
    await named('Jill');
    await showScreen(tester);
    await tester.tap(find.text('+ relationship'));
    await tester.pumpAndSettle();
    TextButton save() => tester.widget(find.widgetWithText(TextButton, 'Save'));

    expect(save().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Description'), 'x');
    await tester.pump();
    expect(save().onPressed, isNull); // no type or person yet
    await tester.tap(find.text('boss'));
    await tester.pump();
    expect(save().onPressed, isNull); // no person yet
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(saved().details, isEmpty);
  });

  testWidgets('a happening starts now at the known place where the phone is', (
    tester,
  ) async {
    await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, 1),
      location: const GeoPoint(47.0, -122.0),
      place: 'Park',
    );
    await showScreen(tester, here: const GeoPoint(47.0, -122.0));

    await addDetail(tester, 'happening', 'Picnic');

    final happening = saved().details.single;
    expect(happening.kind, DetailKind.happening);
    expect(happening.place, 'Park');
    expect(find.textContaining(', Park'), findsOneWidget);
  });

  testWidgets('a relationship reads "My boss is Jill" and follows her name', (
    tester,
  ) async {
    final jill = await named('Jill');
    await showScreen(tester);

    await addDetail(
      tester,
      'relationship',
      'Since 2020',
      fill: () async {
        await tester.tap(find.text('boss'));
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jill').last);
        await tester.pumpAndSettle();
      },
    );

    final r = saved().details.single;
    expect(
      [r.kind, r.label, r.targetId],
      [DetailKind.relationship, 'boss', jill.id],
    );
    expect(find.text('My boss is Jill'), findsOneWidget);

    await repository.save(jill.withField('name', 'Jillian'));
    memory = saved();
    await tester.pumpWidget(const SizedBox());
    await showScreen(tester);
    await tester.pump();
    expect(find.text('My boss is Jillian'), findsOneWidget);
  });

  testWidgets('a relationship to someone in the trash reads "someone '
      'removed"', (tester) async {
    final jill = await named('Jill');
    memory = memory.withDetails([
      Detail(
        id: 'r',
        text: 'Kind',
        at: DateTime(2026),
        type: DetailKind.relationship,
        label: 'boss',
        targetId: jill.id,
      ),
    ]);
    await repository.trash(jill.id, DateTime(2026, 11, 2));
    final bo = await named('Bo');
    await showScreen(tester);

    expect(find.text('My boss is someone removed'), findsOneWidget);

    // Changing it asks for someone new rather than failing.
    await tester.tap(find.text('My boss is someone removed'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    TextButton save() => tester.widget(find.widgetWithText(TextButton, 'Save'));
    expect(save().onPressed, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved().details.single.targetId, bo.id);
    expect(find.text('My boss is Bo'), findsOneWidget);
  });

  testWidgets('a custom anniversary type is offered while it is in use', (
    tester,
  ) async {
    await showScreen(tester);

    await addDetail(
      tester,
      'anniversary',
      'At the cabin',
      fill: () async {
        await tester.enterText(
          find.widgetWithText(TextField, 'Or type a new one'),
          'Baptism',
        );
        await tester.tap(find.text('Choose the first date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      },
    );
    final a = saved().details.single;
    expect([a.kind, a.label], [DetailKind.anniversary, 'Baptism']);
    expect(a.eventDate, isNotNull);

    memory = saved();
    await tester.pumpWidget(const SizedBox());
    await showScreen(tester); // the card reads people when it opens
    await tester.ensureVisible(find.text('+ anniversary'));
    await tester.tap(find.text('+ anniversary'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Baptism'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'wedding'), findsOneWidget);
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
    expect(find.text('Fact'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    expect(repository.saves, isEmpty);
  });

  group('person card details', () {
    late Memory jill;

    Future<void> showWithDetails(WidgetTester tester) async {
      jill = await named('Jill');
      memory = memory.withDetails([
        Detail(id: 'a', text: 'From Seattle', at: DateTime(2026, 11, 1, 10)),
        Detail(
          id: 'b',
          text: 'Sings',
          at: DateTime(2026, 11, 1, 11, 30),
          type: DetailKind.relationship,
          label: 'boss',
          targetId: jill.id,
          points: 3,
        ),
      ]);
      await repository.save(memory);
      repository.saves.clear();
      await showScreen(tester);
    }

    testWidgets('each shows its kind in the corner and its prefix', (
      tester,
    ) async {
      await showWithDetails(tester);

      expect(find.text('Fact'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('My boss is Jill'), findsOneWidget);
    });

    testWidgets('tapping the prefix changes the type, keeping the score', (
      tester,
    ) async {
      await showWithDetails(tester);

      await tester.tap(find.text('My boss is Jill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('friend'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('My friend is Jill'), findsOneWidget);
      final b = repository.saves.last.details.last;
      expect([b.id, b.label, b.text, b.points], ['b', 'friend', 'Sings', 3]);
    });

    testWidgets('delete removes a detail at once; Undo puts it back', (
      tester,
    ) async {
      await showWithDetails(tester);

      await tester.tap(find.byTooltip('Delete Fact'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // snackbar slides in
      expect(find.text('From Seattle'), findsNothing);
      expect(repository.saves.last.details.map((d) => d.id), ['b']);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('From Seattle'), findsOneWidget);
      expect(repository.saves.last.details.map((d) => d.id), ['a', 'b']);

      await tester.enterText(
        find.widgetWithText(TextField, 'From Seattle'),
        'From Tacoma',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(repository.saves.last.details.first.text, 'From Tacoma');
    });

    testWidgets('a late dictation result cannot revive a deleted detail', (
      tester,
    ) async {
      await showWithDetails(tester);

      await tester.tap(find.byTooltip('Speak Description').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Delete Fact'));
      await tester.pump();
      dictation.sayLate('late words');
      await tester.pump(const Duration(seconds: 1));

      expect(repository.saves.last.details.map((d) => d.id), ['b']);
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
            services: testServices(repository, dictation: dictation),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete Fact').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('list'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(saved().details.map((d) => d.id), ['b']);
    });

    testWidgets('leaving without the back handler also clears it', (
      tester,
    ) async {
      memory = memory.withDetails([
        Detail(id: 'a', text: 'Tall', at: DateTime(2026, 11, 1)),
      ]);
      await showScreen(tester);
      await tester.tap(find.byTooltip('Delete Fact'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(const MaterialApp(home: Text('elsewhere')));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsNothing);
      expect(saved().details, isEmpty);
    });
  });

  testWidgets('opening an existing person never fills in their place', (
    tester,
  ) async {
    final cafe = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, 1),
      location: const GeoPoint(47.61, -122.33),
      place: 'Cafe',
    );
    expect(cafe.latest.place, 'Cafe');
    await showScreen(tester); // `memory`: same location, blank place

    await tester.pump(const Duration(seconds: 1));

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Place'))
          .controller!
          .text,
      isEmpty,
    );
    expect(repository.saves, isEmpty);
  });
}
