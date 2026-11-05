import 'package:rememberem/src/memories/detail_list_editor.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/speech/dictated_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/detail_finders.dart';
import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  const mergeTooltip = 'Merge with existing person record';
  late FakeMemoryRepository repository;
  late FakeDictation dictation;
  late Memory memory;

  Future<void> showScreen(
    WidgetTester tester, {
    GeoPoint? here,
    bool justMet = false,
  }) async {
    // A phone-sized screen, so every field is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryEditScreen(
          memory: memory,
          justMet: justMet,
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

  /// Adds an empty row of [kind] on the card.
  Future<void> addRow(WidgetTester tester, String kind) async {
    await tester.ensureVisible(addDetailButtonNamed(kind));
    await tester.tap(addDetailButtonNamed(kind));
    await tester.pumpAndSettle();
  }

  /// Opens the detail card named [label] with its expander.
  Future<void> openRow(WidgetTester tester, String label) async {
    await tester.ensureVisible(openToggle(label));
    await tester.tap(openToggle(label));
    await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets('shows Name, Place and Meeting, and five add buttons with no '
      'empty detail', (tester) async {
    await showScreen(tester);

    for (final label in ['Name', 'Place', 'Meeting']) {
      expect(
        find.widgetWithText(TextField, label.toUpperCase()),
        findsOneWidget,
      );
      // Mics are for the moment of meeting, not a later visit.
      expect(find.byTooltip('Speak $label'), findsNothing);
    }
    for (final kind in [
      'fact',
      'happening',
      'relationship',
      'anniversary',
      'tag',
    ]) {
      expect(addDetailButtonNamed(kind), findsOneWidget);
    }
    // No detail card, so nothing to open.
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.text(DetailListEditor.nothingYet), findsNothing);
    expect(find.textContaining('47.61, -122.33'), findsOneWidget);
  });

  testWidgets('Fred speaks into each field and it all saves by itself', (
    tester,
  ) async {
    await showScreen(tester, justMet: true);

    await speakInto(tester, 'Name', 'Alex Davis');
    await speakInto(tester, 'Place', 'Stake Center');
    await speakInto(tester, 'Meeting', 'Sunday Meetings');
    await tester.pump(const Duration(seconds: 1));

    expect(find.widgetWithText(TextField, 'Alex Davis'), findsOneWidget);
    expect(saved().field(MemoryField.name), 'Alex Davis');
    expect(saved().latest.place, 'Stake Center');
    expect(saved().latest.meeting, 'Sunday Meetings');
  });

  testWidgets('words appear while still being spoken', (tester) async {
    await showScreen(tester, justMet: true);

    await tester.tap(find.byTooltip('Speak Name'));
    await tester.pump();
    dictation.say('Alex');
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Alex'), findsOneWidget);
    expect(find.byTooltip('Stop listening'), findsOneWidget);
  });

  testWidgets('dictation adds to text already typed', (tester) async {
    await showScreen(tester, justMet: true);

    await tester.enterText(find.widgetWithText(TextField, 'MEETING'), 'Choir');
    await speakInto(tester, 'Meeting', 'practice');

    expect(find.text('Choir practice'), findsOneWidget);
  });

  testWidgets('leaving the screen saves a change straight away', (
    tester,
  ) async {
    await showScreen(tester);
    await tester.enterText(find.widgetWithText(TextField, 'NAME'), 'Alex');

    await tester.pumpWidget(const SizedBox());

    expect(saved().field(MemoryField.name), 'Alex');
  });

  testWidgets('explains when speech recognition is unavailable', (
    tester,
  ) async {
    dictation = FakeDictation(available: false);
    await showScreen(tester, justMet: true);

    await tester.tap(find.byTooltip('Speak Name'));
    await tester.pump();

    expect(find.textContaining("Dictation isn't available"), findsOneWidget);
    expect(find.byTooltip('Speak Name'), findsOneWidget);
  });

  testWidgets('someone just met can be deleted at once, not to the trash', (
    tester,
  ) async {
    await showScreen(tester, justMet: true);
    expect(find.text(MemoryEditScreen.askedText), findsOneWidget);

    await tester.tap(find.text('Delete now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.purges, [memory.id]);
    expect(repository.stored, isEmpty);
    expect(find.byType(MemoryEditScreen), findsNothing);
  });

  testWidgets('Delete now asks first; Cancel keeps them', (tester) async {
    await showScreen(tester, justMet: true);

    await tester.tap(find.text('Delete now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.purges, isEmpty);
    expect(saved().trashedAt, isNull);
    expect(find.byType(MemoryEditScreen), findsOneWidget);
  });

  testWidgets('someone opened from the list has no Delete now', (tester) async {
    await showScreen(tester);

    expect(find.text('Delete now'), findsNothing);
  });

  testWidgets('says so when the phone has no offline speech pack', (
    tester,
  ) async {
    await showScreen(tester, justMet: true);

    await tester.tap(find.byTooltip('Speak Name'));
    await tester.pump();
    dictation.lackSpeechPack();
    await tester.pump();

    expect(find.text(DictatedTextField.noSpeechPack), findsOneWidget);
    expect(find.byTooltip('Speak Name'), findsOneWidget);
  });

  testWidgets('a fact is typed where it was added, and kept on leaving', (
    tester,
  ) async {
    await showScreen(tester);

    await addRow(tester, 'fact');
    // The new card is open, and the screen did not change.
    expect(find.byType(MemoryEditScreen), findsOneWidget);
    await tester.enterText(descriptionField(), 'Tall');
    await tester.pumpWidget(const SizedBox());

    final fact = saved().details.single;
    expect([fact.kind, fact.text], [DetailKind.fact, 'Tall']);
  });

  testWidgets('a fact can be spoken into its row', (tester) async {
    await showScreen(tester);

    await addRow(tester, 'fact');
    await speakInto(tester, 'Description', 'Sings in the choir');
    await tester.pump(const Duration(seconds: 1));

    expect(saved().details.single.text, 'Sings in the choir');
  });

  testWidgets('an added row left empty is never saved', (tester) async {
    await showScreen(tester);

    await addRow(tester, 'anniversary');
    await tester.pumpWidget(const SizedBox());

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

    await addRow(tester, 'happening');
    await tester.enterText(descriptionField(), 'Picnic');
    await tester.pump(const Duration(seconds: 1));

    final happening = saved().details.single;
    expect(
      [happening.kind, happening.place, happening.text],
      [DetailKind.happening, 'Park', 'Picnic'],
    );
    expect(find.text('Park'), findsOneWidget);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.expand_less_rounded),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('· Park - Picnic'), findsOneWidget);
  });

  testWidgets('a happening left empty is not saved, even once its place '
      'is found', (tester) async {
    await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, 1),
      location: const GeoPoint(47.0, -122.0),
      place: 'Park',
    );
    await showScreen(tester, here: const GeoPoint(47.0, -122.0));

    await addRow(tester, 'happening');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());

    expect(saved().details, isEmpty);
  });

  /// Makes a type through the New chip's dialog.
  Future<void> newType(WidgetTester tester, String tip, String name) async {
    await tester.tap(find.byTooltip(tip));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name').last, name);
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('the New chip asks for a name: Add chooses it, Cancel changes '
      'nothing, and a name already listed chooses that one', (tester) async {
    await named('Jill');
    await showScreen(tester);
    await addRow(tester, 'relationship');
    await tester.tap(find.text('boss'));
    await tester.pumpAndSettle();

    // Cancel keeps the chosen type.
    await tester.tap(find.byTooltip('New relationship type'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name').last,
      'cousin',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(saved().details.single.label, 'boss');
    expect(find.widgetWithText(ChoiceChip, 'cousin'), findsNothing);

    // A blank name cannot be added.
    await tester.tap(find.byTooltip('New relationship type'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name').last, '  ');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Add'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Add makes a new chip and chooses it.
    await newType(tester, 'New relationship type', 'cousin');
    await tester.pump(const Duration(seconds: 1));
    expect(saved().details.single.label, 'cousin');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'cousin'))
          .selected,
      isTrue,
    );

    // A name matching a listed chip (by normalised key) chooses that chip.
    await newType(tester, 'New relationship type', ' Boss ');
    await tester.pump(const Duration(seconds: 1));
    expect(saved().details.single.label, 'boss');
    expect(find.widgetWithText(ChoiceChip, 'boss'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Boss'), findsNothing);
  });

  testWidgets('a relationship asks Who first, shows faces, and is kept '
      'with no description', (tester) async {
    final jill = await named('Jill');
    await showScreen(tester);

    await addRow(tester, 'relationship');
    final who = find.byType(DropdownButtonFormField<String>);
    final newChip = find.byType(ActionChip);
    expect(tester.getTopLeft(who).dy, lessThan(tester.getTopLeft(newChip).dy));
    await tester.tap(who);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(DropdownMenuItem<String>).last,
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Jill').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('boss'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());

    final r = saved().details.single;
    expect(
      [r.kind, r.label, r.targetId, r.text],
      [DetailKind.relationship, 'boss', jill.id, ''],
    );
  });

  testWidgets('a relationship row reads its type and person before its '
      'text and follows her name', (tester) async {
    final jill = await named('Jill');
    memory = memory.withDetails([
      Detail(
        id: 'r',
        text: 'Since 2020',
        at: DateTime(2026),
        type: DetailKind.relationship,
        label: 'boss',
        targetId: jill.id,
      ),
    ]);
    await repository.save(memory);
    await showScreen(tester);
    await tester.pump();
    expect(find.text('Boss: Jill - Since 2020'), findsOneWidget);
    expect(openToggle('Relationship Boss Jill'), findsOneWidget);

    await repository.save(jill.withField('name', 'Jillian'));
    await tester.pumpWidget(const SizedBox());
    await showScreen(tester);
    await tester.pump();
    expect(find.text('Boss: Jillian - Since 2020'), findsOneWidget);
  });

  testWidgets('a relationship to someone in the trash reads "someone '
      'removed" and can be pointed at someone new', (tester) async {
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
    await tester.pump();

    const label = 'Relationship Boss someone removed';
    expect(find.text('Boss: someone removed - Kind'), findsOneWidget);
    await tester.tap(openToggle(label));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bo').last);
    await tester.pumpAndSettle();

    expect(saved().details.single.targetId, bo.id);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.expand_less_rounded),
    );
    await tester.pumpAndSettle();
    expect(find.text('Boss: Bo - Kind'), findsOneWidget);
  });

  testWidgets('a custom anniversary type is offered while it is in use', (
    tester,
  ) async {
    await showScreen(tester);

    await addRow(tester, 'anniversary');
    await tester.tap(find.byTooltip('New anniversary type'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextField, 'Name').last,
      'Baptism',
    );
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('+ date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final a = saved().details.single;
    expect([a.kind, a.label], [DetailKind.anniversary, 'Baptism']);
    expect(a.eventDate, isNotNull);

    memory = saved();
    await tester.pumpWidget(const SizedBox());
    await showScreen(tester); // the card reads people when it opens
    await tester.pump();
    await addRow(tester, 'anniversary');
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
    expect(openToggle('Fact'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    expect(repository.saves, isEmpty);
  });

  testWidgets('the title is the name as typed, or Unknown', (tester) async {
    await showScreen(tester);
    expect(find.widgetWithText(AppBar, 'Unknown'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'NAME'), 'Ann Lee');
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Ann Lee'), findsOneWidget);
    expect(find.text('New person'), findsNothing);
  });

  testWidgets(
    'the photo is 136 x 170 with crop on its lower right (28 dp to see, '
    '48 dp to tap); the fields sit to its right and the time, the '
    'coordinates and Merge on one line below it',
    (tester) async {
      await showScreen(tester);

      final photo = tester.getRect(find.byKey(const ValueKey('photo-0')));
      expect(photo.size, const Size(136, 170));
      final crop = tester.getRect(find.byTooltip('Crop'));
      expect(photo.contains(crop.center), isTrue);
      expect(crop.center.dx, greaterThan(photo.center.dx));
      expect(crop.center.dy, greaterThan(photo.center.dy));
      expect(crop.size, const Size(28, 28));
      // The tap area is 48 dp, whatever is drawn.
      final handle = tester.ensureSemantics();
      final area = tester.getSemantics(find.byTooltip('Crop')).rect;
      expect(area.width, greaterThanOrEqualTo(48));
      expect(area.height, greaterThanOrEqualTo(48));
      handle.dispose();
      expect(find.text('Crop'), findsNothing); // an icon only

      for (final label in ['NAME', 'PLACE', 'MEETING']) {
        final field = tester.getRect(find.widgetWithText(TextField, label));
        expect(field.left, greaterThan(photo.right));
        expect(field.top, lessThan(photo.bottom));
      }

      final merge = tester.getRect(find.byTooltip(mergeTooltip));
      final clock = tester.getRect(find.byTooltip('Change date and time'));
      final pin = tester.getRect(find.byTooltip('Change location'));
      for (final r in [merge, clock, pin]) {
        expect(r.top, greaterThanOrEqualTo(photo.bottom));
        expect(r.center.dy, closeTo(clock.center.dy, 1));
      }
      expect(clock.right, lessThan(pin.left));
      expect(pin.right, lessThanOrEqualTo(merge.left));
      expect(find.text('Merge'), findsOneWidget);
    },
  );

  testWidgets('detail text follows the size in Settings', (tester) async {
    memory = memory.withDetails([
      Detail(id: 'a', text: 'From Seattle', at: DateTime(2026)),
    ]);
    Future<double> fontSize(int percent) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryEditScreen(
            memory: memory,
            services: testServices(
              repository,
              settings: AppSettings(
                detailTextPercent: percent,
                streetMaps: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // The second time, the card is still open.
      if (openToggle('Fact').evaluate().isNotEmpty) {
        await openRow(tester, 'Fact');
      }
      final field = tester.element(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == 'From Seattle',
        ),
      );
      return MediaQuery.textScalerOf(field).scale(10);
    }

    expect(await fontSize(80), closeTo(8, 1e-9));
    expect(await fontSize(120), closeTo(12, 1e-9));
  });

  group('relationships list', () {
    late Memory jill;
    late Memory cy;

    Future<void> showRelated(WidgetTester tester) async {
      jill = await named('Jill');
      cy = await named('Cy');
      final ann = await named('Ann');
      memory = memory.withField('name', 'Bo').withDetails([
        Detail(
          id: 'r',
          text: '',
          at: DateTime(2026),
          type: DetailKind.relationship,
          label: 'boss',
          targetId: jill.id,
        ),
      ]);
      await repository.save(memory);
      await repository.save(
        cy.withDetails([
          Detail(
            id: 'c',
            text: '',
            at: DateTime(2026),
            type: DetailKind.relationship,
            label: 'brother',
            targetId: memory.id,
          ),
        ]),
      );
      await repository.save(
        ann.withDetails([
          Detail(
            id: 't',
            text: '',
            at: DateTime(2026),
            type: DetailKind.relationship,
            label: 'coach',
            targetId: memory.id,
          ),
        ]),
      );
      await repository.trash(ann.id, DateTime(2026, 11, 2));
      await showScreen(tester);
      await tester.pump();
    }

    testWidgets('lists both ways with photos, never someone in the trash', (
      tester,
    ) async {
      await showRelated(tester);

      // Once for the details' heading, once for this list of people.
      expect(find.textContaining('RELATIONSHIPS'), findsNWidgets(2));
      expect(find.widgetWithText(ListTile, 'Boss'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Bo is their brother'),
        findsOneWidget,
      );
      expect(find.textContaining('coach'), findsNothing);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Bo is their brother'),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    });

    testWidgets('following a link back to someone already open returns to '
        'that page instead of opening a second one', (tester) async {
      await showRelated(tester);
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Cy'));
      await tester.tap(find.widgetWithText(ListTile, 'Cy'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Cy'), findsOneWidget);

      // On Cy's page, Bo is listed as Cy's brother: back to the first page.
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Bo'));
      await tester.tap(find.widgetWithText(ListTile, 'Bo'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryEditScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Bo'), findsOneWidget);
    });

    testWidgets('tapping someone saves this page and opens theirs', (
      tester,
    ) async {
      await showRelated(tester);
      await tester.enterText(find.widgetWithText(TextField, 'NAME'), 'Bob');

      await tester.ensureVisible(find.widgetWithText(ListTile, 'Cy'));
      await tester.tap(find.widgetWithText(ListTile, 'Cy'));
      await tester.pumpAndSettle();

      expect(saved().displayName, 'Bob');
      expect(find.widgetWithText(AppBar, 'Cy'), findsOneWidget);
    });
  });

  group('person card details', () {
    late Memory jill;
    const relLabel = 'Relationship Boss Jill';

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
      await tester.pump();
    }

    testWidgets('each detail is a closed card with its kind and data', (
      tester,
    ) async {
      await showWithDetails(tester);

      expect(find.text('From Seattle'), findsOneWidget);
      expect(find.text('Boss: Jill - Sings'), findsOneWidget);
      expect(openToggle('Fact'), findsOneWidget);
      expect(openToggle(relLabel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DetailListEditor),
          matching: find.byType(DictatedTextField),
        ),
        findsNothing,
      );
    });

    testWidgets('changing the type in place keeps the score', (tester) async {
      await showWithDetails(tester);

      await tester.tap(openToggle(relLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('friend'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.expand_less_rounded).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Friend: Jill - Sings'), findsOneWidget);
      final b = repository.saves.last.details.last;
      expect([b.id, b.label, b.text, b.points], ['b', 'friend', 'Sings', 3]);
    });

    testWidgets('delete removes a detail at once; Undo puts it back', (
      tester,
    ) async {
      await showWithDetails(tester);

      await openRow(tester, 'Fact');
      await tester.tap(find.byTooltip('Delete Fact'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // snackbar slides in
      expect(find.text('From Seattle'), findsNothing);
      expect(repository.saves.last.details.map((d) => d.id), ['b']);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('From Seattle'), findsOneWidget);
      expect(repository.saves.last.details.map((d) => d.id), ['a', 'b']);

      // Back it comes closed; open it and edit.
      await openRow(tester, 'Fact');
      await tester.enterText(descriptionField(), 'From Tacoma');
      await tester.pump(const Duration(seconds: 1));
      expect(repository.saves.last.details.first.text, 'From Tacoma');
    });

    testWidgets('a late dictation result cannot revive a deleted detail', (
      tester,
    ) async {
      await showWithDetails(tester);

      await openRow(tester, 'Fact');
      await tester.tap(find.byTooltip('Speak Description'));
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

      await tester.tap(openToggle('Fact').first);
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
      await openRow(tester, 'Fact');
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
          .widget<TextField>(find.widgetWithText(TextField, 'PLACE'))
          .controller!
          .text,
      isEmpty,
    );
    expect(repository.saves, isEmpty);
  });
}
