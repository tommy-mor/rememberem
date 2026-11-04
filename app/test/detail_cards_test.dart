import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/rememberem_theme.dart';
import 'package:rememberem/src/memories/detail_list_editor.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/pulsing_button.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/detail_finders.dart';
import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
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

  Future<void> withDetails(List<Detail> details) async {
    memory = memory.withDetails(details);
    await repository.save(memory);
  }

  /// A short pump: an anniversary's "+ date" pulses, so never settle.
  Future<void> beat(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 500));

  Detail tag({String? label, String text = 'x'}) => Detail(
    id: 't',
    text: text,
    at: DateTime(2026),
    type: DetailKind.tag,
    label: label,
  );

  Detail anniversary({DateTime? on}) => Detail(
    id: 'a',
    text: 'Big day',
    at: DateTime(2026),
    type: DetailKind.anniversary,
    label: 'wedding',
    eventDate: on,
  );

  setUp(() async {
    repository = FakeMemoryRepository();
    memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
    );
  });

  testWidgets('five headings in order, and no "Details" title', (tester) async {
    await showCard(tester);

    final tops = [
      for (final kind in DetailKind.values)
        tester.getTopLeft(find.text(kind.plural)).dy,
    ];
    expect(DetailKind.values.map((k) => k.plural), [
      'Facts',
      'Happenings',
      'Relationships',
      'Anniversaries',
      'Tags',
    ]);
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(5));
    expect(find.text('Details'), findsNothing);
    for (final kind in DetailKind.values) {
      expect(addDetailButton(kind), findsOneWidget);
    }
  });

  testWidgets('the + on Tags adds an open tag and takes no focus', (
    tester,
  ) async {
    await showCard(tester);

    await tester.ensureVisible(addDetailButton(DetailKind.tag));
    await tester.tap(addDetailButton(DetailKind.tag));
    await beat(tester);

    expect(find.byTooltip('Close Tag'), findsOneWidget);
    expect(descriptionField(), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
  });

  testWidgets('a closed card is one line of its summary', (tester) async {
    await withDetails([
      Detail(id: 'f', text: 'Tall ' * 60, at: DateTime(2026)),
    ]);
    await showCard(tester);

    final line = tester.widget<Text>(find.textContaining('Tall Tall'));
    expect(line.maxLines, 1);
    expect(line.softWrap, isFalse);
    expect(line.overflow, TextOverflow.ellipsis);
    expect(find.byType(EditableText), findsNWidgets(3)); // only the top fields
  });

  testWidgets('a tag with no type, and an anniversary with no date, say so '
      'in red on the closed card', (tester) async {
    await withDetails([tag(), anniversary()]);
    await showCard(tester);

    final error = Theme.of(tester.element(find.byType(Scaffold)))
        .colorScheme
        .error;
    for (final problem in [DetailListEditor.noTag, DetailListEditor.noDate]) {
      expect(find.text(problem), findsOneWidget);
      expect(tester.widget<Text>(find.text(problem)).style?.color, error);
    }
    expect(DetailListEditor.noTag, 'No tag chosen');
    expect(DetailListEditor.noDate, 'No date');
  });

  testWidgets('a complete tag and anniversary show no problem', (tester) async {
    await withDetails([tag(label: 'choir'), anniversary(on: DateTime(2010))]);
    await showCard(tester);

    expect(find.text('No tag chosen'), findsNothing);
    expect(find.text('No date'), findsNothing);
  });

  testWidgets('the close toggle closes an open card', (tester) async {
    await withDetails([Detail(id: 'f', text: 'Tall', at: DateTime(2026))]);
    await showCard(tester);

    await tester.tap(openToggle('Fact'));
    await beat(tester);
    expect(descriptionField(), findsOneWidget);

    await tester.tap(find.byTooltip('Close Fact'));
    await beat(tester);
    expect(descriptionField(), findsNothing);
    expect(openToggle('Fact'), findsOneWidget);
  });

  testWidgets('tapping outside an open card, off any field, closes it', (
    tester,
  ) async {
    await withDetails([Detail(id: 'f', text: 'Tall', at: DateTime(2026))]);
    await showCard(tester);
    await tester.tap(openToggle('Fact'));
    await beat(tester);

    await tester.tap(find.text('Tags'));
    await beat(tester);

    expect(descriptionField(), findsNothing);
  });

  testWidgets('the mic shows only in an open card', (tester) async {
    await withDetails([Detail(id: 'f', text: 'Tall', at: DateTime(2026))]);
    await showCard(tester);
    expect(find.byTooltip('Speak Description'), findsNothing);

    await tester.tap(openToggle('Fact'));
    await beat(tester);
    expect(find.byTooltip('Speak Description'), findsOneWidget);

    await tester.tap(find.byTooltip('Close Fact'));
    await beat(tester);
    expect(find.byTooltip('Speak Description'), findsNothing);
  });

  testWidgets('a dateless anniversary offers + date, which opens the date '
      'picker; once a date is chosen nothing pulses', (tester) async {
    await withDetails([anniversary()]);
    await showCard(tester);
    await tester.tap(openToggle('Anniversary Wedding'));
    await beat(tester);

    expect(find.text('+ date'), findsOneWidget);
    await tester.tap(find.text('+ date'));
    await beat(tester);
    await beat(tester);

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await beat(tester);
    await beat(tester);

    expect(find.text('+ date'), findsNothing);
    expect(find.byType(PulsingButton), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('open happenings and tags say no "When" or "Where"', (
    tester,
  ) async {
    await withDetails([
      Detail(
        id: 'h',
        text: 'Picnic',
        at: DateTime(2026, 5, 3, 10),
        type: DetailKind.happening,
        place: 'Park',
      ),
      tag(label: 'choir')
          .copyWith(place: () => 'Hall', eventDate: () => DateTime(2026, 6, 1)),
    ]);
    await showCard(tester);
    Finder opener(String kind) => find.byWidgetPredicate(
      (w) => w is Icon && (w.semanticLabel ?? '').startsWith('Open $kind'),
    );
    await tester.tap(opener('Happening'));
    await beat(tester);
    expect(find.text('Park'), findsOneWidget);
    for (final text in ['When it happened', 'Where it happened']) {
      expect(find.text(text), findsNothing);
    }

    await tester.tap(opener('Tag'));
    await beat(tester);
    expect(find.text('Hall'), findsOneWidget);
    for (final text in ['When', 'Where']) {
      expect(find.text(text), findsNothing);
    }
  });

  testWidgets('"New" for a type is italic, a shade off the card', (
    tester,
  ) async {
    await withDetails([tag(label: 'choir')]);
    await showCard(tester);
    await tester.tap(openToggle('Tag Choir'));
    await beat(tester);

    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect((chip.label as Text).style?.fontStyle, FontStyle.italic);
    final theme = Theme.of(tester.element(find.byType(ActionChip)));
    expect(chip.backgroundColor, isNot(DetailListEditor.tintOf(theme)));
    expect(
      chip.backgroundColor!.computeLuminance(),
      lessThan(DetailListEditor.tintOf(theme).computeLuminance()),
    );
  });

  testWidgets('Name, Place and Meeting hint faintly, in italics', (
    tester,
  ) async {
    await showCard(tester);

    var hints = 0;
    for (final hint in ['Unknown', 'unknown']) {
      for (final text in tester.widgetList<Text>(find.text(hint))) {
        if (text.style?.color == null) continue; // the title, not a hint
        hints++;
        expect(text.style!.fontStyle, FontStyle.italic);
        expect(text.style!.color!.a, closeTo(170 / 255, 0.01));
      }
    }
    expect(hints, 3);
    // Place and Meeting both say "unknown".
    expect(find.text('unknown'), findsNWidgets(2));
  });

  testWidgets('Undo and Redo sit in a bar fixed at the foot of the page', (
    tester,
  ) async {
    await showCard(tester);

    final bar = tester
        .widget<Scaffold>(find.byType(Scaffold))
        .bottomNavigationBar;
    expect(bar, isNotNull);
    expect(
      find.descendant(
        of: find.byWidget(bar!),
        matching: find.byTooltip('Undo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a happening without a place offers + place', (tester) async {
    await withDetails([
      Detail(
        id: 'h',
        text: 'Picnic',
        at: DateTime(2026, 5, 3, 10),
        type: DetailKind.happening,
      ),
    ]);
    await showCard(tester);
    await tester.tap(openToggle('Happening 3 May 2026'));
    await beat(tester);

    expect(find.widgetWithText(OutlinedButton, '+ place'), findsOneWidget);
  });

  test('a card is a shade darker than a light page and lighter than a dark '
      'one', () {
    final light = RememberemTheme.light(AppSettings());
    final dark = RememberemTheme.dark(AppSettings(darkMode: true));

    expect(
      DetailListEditor.tintOf(light).computeLuminance(),
      lessThan(light.scaffoldBackgroundColor.computeLuminance()),
    );
    expect(
      DetailListEditor.tintOf(dark).computeLuminance(),
      greaterThan(dark.scaffoldBackgroundColor.computeLuminance()),
    );
  });

  test('placeholders are italic', () {
    for (final theme in [
      RememberemTheme.light(AppSettings()),
      RememberemTheme.dark(AppSettings(darkMode: true)),
    ]) {
      expect(theme.inputDecorationTheme.hintStyle?.fontStyle, FontStyle.italic);
    }
  });
}
