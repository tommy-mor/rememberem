import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/filter_bar.dart';
import 'package:rememberem/src/memories/filter_row.dart';
import 'package:rememberem/src/memories/filter_match_lines.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

void main() {
  late FakeMemoryRepository repository;
  late AppServices services;

  AppServices makeServices() => AppServices(
    repository: repository,
    capture: PortraitCapture(
      repository: repository,
      faceLocator: _NoFaces(),
      workFolder: Directory.systemTemp,
    ),
    dictation: FakeDictation(),
    location: DeviceLocation(),
  );

  Future<Memory> person(
    String name,
    String place, {
    List<String> details = const [],
  }) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, repository.stored.length + 1),
      place: place,
    );
    final named = memory.withField('name', name).withDetails([
      for (final (i, text) in details.indexed)
        Detail(id: '${memory.id}-$i', text: text, at: DateTime.utc(2026)),
    ]);
    await repository.save(named);
    return named;
  }

  Future<void> showMatching(
    WidgetTester tester, {
    List<FilterCondition> filters = const [],
    String? note,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = makeServices();
    if (filters.isNotEmpty || note != null) {
      services.listFilters.show(filters, note: note);
    }
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: MemoryListScreen(
          services: services,
          routeObserver: observer,
          onMeetSomeone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addFilter(WidgetTester tester, String kind) async {
    await tester.tap(find.byTooltip('Add filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kind).last);
    await tester.pumpAndSettle();
  }

  setUp(() => repository = FakeMemoryRepository());

  testWidgets('the list starts with no filters and offers every kind', (
    tester,
  ) async {
    await person('Alex', 'Cafe');
    await showMatching(tester);

    expect(find.byType(FilterRow), findsNothing);
    expect(find.text('Clear all'), findsNothing);
    await tester.tap(find.byTooltip('Add filter'));
    await tester.pumpAndSettle();
    for (final kind in [
      'Place',
      'Meeting',
      'Name contains',
      'Details contain',
      'Date range',
      'Anniversary',
      'Tag',
    ]) {
      expect(find.text(kind), findsOneWidget);
    }
  });

  testWidgets('filters stack, two of one kind included; removing one '
      'widens the list again', (tester) async {
    await person('Alex', 'Cafe', details: ['Tall', 'Plays chess']);
    await person('Sam', 'Cafe', details: ['Tall']);
    await person('Kim', 'Park', details: ['Plays chess']);
    await showMatching(tester);

    await addFilter(tester, 'Details contain');
    await tester.enterText(find.byType(TextField).last, 'tall');
    await addFilter(tester, 'Details contain');
    await tester.enterText(find.byType(TextField).last, 'chess');
    await tester.pump();
    expect(find.text('1 person'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Details contain filter').first);
    await tester.pumpAndSettle();
    expect(find.text('2 people'), findsOneWidget);
    // The remaining row kept its own text.
    expect(find.widgetWithText(TextField, 'chess'), findsOneWidget);
  });

  testWidgets('name contains "unknown" finds the unnamed', (tester) async {
    await person('Alex', 'Cafe');
    await person('', 'Cafe');
    await showMatching(tester);

    await addFilter(tester, 'Name contains');
    await tester.enterText(find.byType(TextField).last, 'unknown');
    await tester.pump();

    expect(find.text('1 person'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('a date range keeps those met on its days', (tester) async {
    await person('Alex', 'Cafe'); // 1 Nov
    await person('Sam', 'Cafe'); // 2 Nov
    await person('Kim', 'Cafe'); // 3 Nov
    await showMatching(
      tester,
      filters: [DateRangeFilter(DateTime(2026, 11, 2), DateTime(2026, 11, 3))],
    );

    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('Nov 2, 2026 – Nov 3, 2026'), findsOneWidget);
  });

  testWidgets('it can open with a filter and a note', (tester) async {
    await person('Alex', 'Cafe');
    await person('', 'Cafe');
    await showMatching(
      tester,
      filters: [const NameFilter('unknown')],
      note: 'Add their names while you remember.',
    );

    expect(find.text('Add their names while you remember.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'unknown'), findsOneWidget);
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('lists active people only, with a count', (tester) async {
    await person('Alex', 'Cafe');
    final gone = await person('Gone', 'Cafe');
    await repository.trash(gone.id, DateTime(2026, 12, 1));

    await showMatching(tester);

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Gone'), findsNothing);
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('choosing a place narrows the list', (tester) async {
    await person('Alex', 'Cafe');
    await person('Sam', 'Park');
    await showMatching(tester);
    expect(find.text('2 people'), findsOneWidget);

    // Adding it opens the choice at once.
    await addFilter(tester, 'Place');
    expect(find.text('2 people'), findsOneWidget); // not chosen yet
    await tester.tap(find.text('Park').last);
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('details text filters, case-insensitively', (tester) async {
    await person('Alex', 'Cafe', details: ['Plays CHESS']);
    await person('Sam', 'Cafe', details: ['Tall']);
    await showMatching(tester);
    await addFilter(tester, 'Details contain');

    await tester.enterText(
      find.widgetWithText(TextField, 'Details contain'),
      'chess',
    );
    await tester.pump();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);
  });

  testWidgets('a match opens their card; an edit shows on return', (
    tester,
  ) async {
    await person('Alex', 'Cafe');
    await showMatching(tester);

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Alex'),
      'Alex Davis',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Alex Davis'), findsOneWidget);
  });

  testWidgets('a chosen place that no one has any more keeps working', (
    tester,
  ) async {
    final alex = await person('Alex', 'Cafe');
    await person('Sam', 'Park');
    await showMatching(tester);
    await addFilter(tester, 'Place');
    await tester.tap(find.text('Cafe').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cafe'), 'Library');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No one matches.'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget); // still the chosen place
    expect(repository.stored[alex.id]!.latest.place, 'Library');
  });

  testWidgets('choosing a sort twice reverses it; unnamed people stay last', (
    tester,
  ) async {
    await person('Cy Adams', 'Cafe'); // 1 Nov
    await person('', 'Cafe'); // 2 Nov
    await person('Ann Zed', 'Cafe'); // 3 Nov
    await showMatching(tester);

    List<String> order() => [
      for (final t in tester.widgetList<ListTile>(find.byType(ListTile)))
        (t.title! as Text).data!,
    ];
    expect(order(), ['Ann Zed', 'Cy Adams', 'Unknown']); // newest first

    Future<void> sortBy(String label) async {
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(label).last);
      await tester.pumpAndSettle();
    }

    await sortBy('Last name');
    expect(order(), ['Cy Adams', 'Ann Zed', 'Unknown']);
    await sortBy('Last name');
    expect(order(), ['Ann Zed', 'Cy Adams', 'Unknown']);
    await sortBy('First name');
    expect(order(), ['Ann Zed', 'Cy Adams', 'Unknown']);
  });

  testWidgets('a date range shows why each person matches', (tester) async {
    final alex = await person('Alex', 'Cafe'); // met 1 Nov
    await repository.save(
      alex.withDetails([
        Detail(
          id: 'w',
          text: '',
          at: DateTime.utc(2026),
          type: DetailKind.anniversary,
          label: 'wedding',
          eventDate: DateTime(2010, 11, 1),
        ),
        Detail(id: 'f', text: 'Tall', at: DateTime(2026, 11, 1)),
      ]),
    );
    await person('Sam', 'Cafe'); // met 2 Nov
    await showMatching(
      tester,
      filters: [DateRangeFilter(DateTime(2026, 11, 1), DateTime(2026, 11, 1))],
    );

    expect(find.text('1 person'), findsOneWidget);
    expect(find.text(FilterBar.dateHint), findsOneWidget);
    expect(find.text('Wedding: 1 Nov 2010'), findsOneWidget);
    expect(find.text('Photo · 1 Nov 2026'), findsOneWidget);
    expect(find.textContaining('Tall'), findsNothing); // a fact has no date
  });

  testWidgets('details contain shows the matching details, the words in '
      'bold, and finds a type too', (tester) async {
    final alex = await person('Alex', 'Cafe', details: ['Sings bass']);
    await repository.save(
      alex.withDetails([
        ...alex.details,
        Detail(
          id: 't',
          text: '',
          at: DateTime.utc(2026),
          type: DetailKind.tag,
          label: 'Bass choir',
        ),
      ]),
    );
    await showMatching(tester, filters: [const DetailsFilter('bass')]);

    final lines = FilterMatchLines.linesFor(
      repository.stored[alex.id]!,
      services.listFilters.active,
      (_) => null,
    );
    expect(lines.map((l) => l.text), ['Fact · Sings bass', 'Tag · Bass choir']);
    expect(lines.first.bold, [(13, 17)]);
    expect(lines.last.bold, [(6, 10)]);
    expect(find.text('Fact · Sings bass', findRichText: true), findsOneWidget);
    final rich = tester.widget<RichText>(
      find.text('Fact · Sings bass', findRichText: true),
    );
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final bass = spans.singleWhere((s) => s.text == 'bass');
    expect(bass.style?.fontWeight, FontWeight.bold);
    expect(spans.firstWhere((s) => s.text == 'Fact · Sings ').style, isNull);
  });

  testWidgets('every matching detail shows, never folded', (tester) async {
    await person('Alex', 'Cafe', details: ['a1', 'a2', 'a3', 'a4', 'a5']);
    await showMatching(tester, filters: [const DetailsFilter('a')]);

    for (var i = 1; i <= 5; i++) {
      expect(find.text('Fact · a$i', findRichText: true), findsOneWidget);
    }
    expect(find.textContaining('more'), findsNothing);
  });

  testWidgets('a tag filter and an anniversary range show the tags and '
      'anniversaries that match', (tester) async {
    final alex = await person('Alex', 'Cafe');
    await repository.save(
      alex.withDetails([
        Detail(
          id: 't',
          text: 'alto',
          at: DateTime.utc(2026),
          type: DetailKind.tag,
          label: 'Choir',
        ),
        Detail(
          id: 'w',
          text: 'at the lake',
          at: DateTime.utc(2026),
          type: DetailKind.anniversary,
          label: 'wedding',
          eventDate: DateTime(2010, 6, 3),
        ),
        Detail(id: 'f', text: 'Sings', at: DateTime.utc(2026)),
      ]),
    );
    await showMatching(
      tester,
      filters: [
        const TagFilter('choir'),
        AnniversaryFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 10)),
      ],
    );

    expect(find.text('Tag · Choir - alto', findRichText: true), findsOneWidget);
    expect(find.textContaining('Wedding', findRichText: true), findsOneWidget);
    expect(find.textContaining('Sings', findRichText: true), findsNothing);
  });

  testWidgets('a detail matching two filters shows once', (tester) async {
    final alex = await person('Alex', 'Cafe');
    await repository.save(
      alex.withDetails([
        Detail(
          id: 't',
          text: 'alto',
          at: DateTime.utc(2026),
          type: DetailKind.tag,
          label: 'Choir',
        ),
      ]),
    );
    await showMatching(
      tester,
      filters: [const TagFilter('choir'), const DetailsFilter('alto')],
    );

    final line = find.text('Tag · Choir - alto', findRichText: true);
    expect(line, findsOneWidget);
    // The words found still show in bold, though the tag filter came first.
    final spans = <TextSpan>[];
    tester.widget<RichText>(line).text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(
      spans.singleWhere((s) => s.text == 'alto').style?.fontWeight,
      FontWeight.bold,
    );
  });

  testWidgets('a relationship reads type, person, then words, with the '
      'words found in bold; an anniversary has no "every"', (tester) async {
    final ann = await person('Ann', 'Cafe');
    final bo = await person('Bo', 'Cafe');
    await repository.save(
      bo.withDetails([
        Detail(
          id: 'r',
          text: 'met at the choir',
          at: DateTime.utc(2026),
          type: DetailKind.relationship,
          label: 'sister',
          targetId: ann.id,
        ),
        Detail(
          id: 'w',
          text: 'by the choir loft',
          at: DateTime.utc(2026),
          type: DetailKind.anniversary,
          label: 'wedding',
          eventDate: DateTime(2010, 6, 3),
        ),
      ]),
    );
    await showMatching(tester, filters: [const DetailsFilter('choir')]);

    final lines = FilterMatchLines.linesFor(
      repository.stored[bo.id]!,
      services.listFilters.active,
      (id) => id == ann.id ? 'Ann' : null,
    );
    expect(lines.map((l) => l.text), [
      'Sister: Ann - met at the choir',
      'Wedding: 3 Jun 2010 - by the choir loft',
    ]);
    expect(lines.first.bold, [(25, 30)]);
    expect(
      find.text('Sister: Ann - met at the choir', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a choice filter opens its list when added; cancelling '
      'removes it', (tester) async {
    await person('Alex', 'Cafe');
    await showMatching(tester);

    await addFilter(tester, 'Place');
    expect(find.text('Cafe'), findsWidgets); // the list is open
    // Each choice in its own box.
    final choice = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Cafe').last,
        matching: find.byType(ListTile),
      ),
    );
    expect(
      (choice.shape! as RoundedRectangleBorder).side.style,
      BorderStyle.solid,
    );
    expect(choice.visualDensity, const VisualDensity(vertical: -4));
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    expect(find.byType(FilterRow), findsNothing);
    expect(services.listFilters.filters, isEmpty);
  });

  testWidgets('a date filter opens its calendar when added; cancelling '
      'removes it', (tester) async {
    await person('Alex', 'Cafe');
    await showMatching(tester);

    await addFilter(tester, 'Date range');
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(services.listFilters.filters, isEmpty);
  });

  testWidgets('a chosen filter does not open again on a rebuild', (
    tester,
  ) async {
    await person('Alex', 'Cafe');
    await person('Sam', 'Park');
    await showMatching(tester);
    await addFilter(tester, 'Place');
    await tester.tap(find.text('Park').last);
    await tester.pumpAndSettle();

    services.listFilters.sortBy(PersonSort.firstName); // rebuilds the bar
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(services.listFilters.added, isNull);
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('a text filter takes the keyboard when added', (tester) async {
    await person('Alex', 'Cafe');
    await showMatching(tester);

    await addFilter(tester, 'Name contains');

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Name contains'),
    );
    expect(field.autofocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('Clear all shows everyone; changing a filter ends the note', (
    tester,
  ) async {
    await person('Alex', 'Cafe');
    await person('', 'Cafe');
    await showMatching(
      tester,
      filters: [const NameFilter('unknown')],
      note: 'Add their names while you remember.',
    );

    await tester.enterText(find.widgetWithText(TextField, 'unknown'), 'unk');
    await tester.pump();
    expect(find.text('Add their names while you remember.'), findsNothing);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('2 people'), findsOneWidget);
    expect(find.byType(FilterMatchLines), findsNothing);
  });
}
