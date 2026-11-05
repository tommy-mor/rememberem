import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/detail_extras_editor.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  late Memory memory;

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> showCard(WidgetTester tester) async {
    phone(tester);
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

  Memory saved() => repository.stored[memory.id]!;

  Future<Memory> withTag(String name, String tag) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, repository.stored.length + 1),
    );
    final tagged = m.withField('name', name).withDetails([
      Detail(
        id: '${m.id}-t',
        text: '',
        at: DateTime.utc(2026),
        type: DetailKind.tag,
        label: tag,
      ),
    ]);
    await repository.save(tagged);
    return tagged;
  }

  Future<void> addTag(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Add a tag'));
    await tester.tap(find.byTooltip('Add a tag'));
    await tester.pumpAndSettle();
  }

  /// Makes a new tag type through the New chip's dialog.
  Future<void> newTag(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('New tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name').last, name);
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  /// Closes the one open card and returns its one-line summary.
  Future<String> closedLine(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.expand_less_rounded),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byWidgetPredicate((w) => w is Text && w.maxLines == 1),
      ),
    );
    return text.data!;
  }

  setUp(() async {
    repository = FakeMemoryRepository();
    memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
    );
  });

  testWidgets('the first tag explains tags, then takes a type and a date '
      'that show before its text', (tester) async {
    await showCard(tester);
    await addTag(tester);

    expect(find.text(DetailExtrasEditor.noTagsYet), findsOneWidget);
    expect(find.text(DetailExtrasEditor.keepTagsKind), findsOneWidget);

    await newTag(tester, 'book club');
    expect(find.text(DetailExtrasEditor.noTagsYet), findsNothing);
    expect(find.text(DetailExtrasEditor.needsType), findsNothing);
    expect(find.byTooltip('Delete Tag Book club'), findsOneWidget);
    expect(await closedLine(tester), 'Book club'); // shown, not just set
    await tester.tap(find.text('Book club'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ date'));
    await tester.tap(find.text('+ date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    final tag = saved().details.single;
    expect([tag.kind, tag.label], [DetailKind.tag, 'book club']);
    expect(tag.eventDate, isNotNull);
    final line = 'Book club · ${DetailPrompt.date(tag.eventDate!)}';
    expect(await closedLine(tester), line);
    await tester.tap(find.text(line));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear the date'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(saved().details.single.eventDate, isNull);
    expect(find.text('+ date'), findsOneWidget);
  });

  testWidgets('tags in use are offered and the explanation is not shown', (
    tester,
  ) async {
    await withTag('Bo', 'Relatives');
    await showCard(tester);
    await addTag(tester);

    expect(find.text(DetailExtrasEditor.noTagsYet), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Relatives'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(saved().details.single.label, 'Relatives');
  });

  testWidgets('a tag takes a place from the map, and it can be cleared', (
    tester,
  ) async {
    var detail = Detail(
      id: 't',
      text: '',
      at: DateTime.utc(2026),
      type: DetailKind.tag,
      label: 'club',
    );
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return DetailExtrasEditor(
                detail: detail,
                ownerId: 'me',
                people: const [],
                photoOf: (m) => throw UnimplementedError(),
                choosePlace: (current) async => 'Park',
                onChanged: (d) => rebuild(() => detail = d),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('+ place'));
    await tester.pumpAndSettle();
    expect(detail.place, 'Park');
    expect(find.text('Park'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear the place'));
    await tester.pumpAndSettle();
    expect(detail.place, isNull);
    expect(find.text('+ place'), findsOneWidget);
  });

  test('the prefix lists the parts a tag has, joined by dots', () {
    String? noName(String id) => null;
    Detail tag({String? label, String? place, DateTime? on}) => Detail(
      id: 't',
      text: '',
      at: DateTime.utc(2026),
      type: DetailKind.tag,
      label: label,
      place: place,
      eventDate: on,
    );
    expect(
      DetailSummary.prefix(
        tag(label: 'relatives', place: 'Park', on: DateTime(2026, 3, 3)),
        noName,
      ),
      'Relatives · Park · 3 Mar 2026 - ',
    );
    expect(DetailSummary.prefix(tag(place: 'Park'), noName), 'Park - ');
    expect(DetailSummary.prefix(tag(), noName), isNull);
    expect(DetailSummary.spokenName(tag(label: 'x'), noName), 'Tag X');
    expect(
      DetailSummary.prefix(
        Detail(id: 'f', text: 'x', at: DateTime.utc(2026)),
        noName,
      ),
      isNull,
    );
  });

  testWidgets('the Tag filter on the list finds people by tag', (tester) async {
    await withTag('Ann', 'Book club');
    await withTag('Bo', 'Relatives');
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryListScreen(
          services: testServices(repository),
          routeObserver: RouteObserver<ModalRoute<void>>(),
          onMeetSomeone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add filter'));
    await tester.pumpAndSettle();
    // Adding it opens its list of tags at once.
    await tester.tap(find.text('Tag').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book club').last);
    await tester.pumpAndSettle();

    expect(find.text('1 person'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bo'), findsNothing);
  });
}
