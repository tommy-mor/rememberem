import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/about/about_screen.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/maps/place_marker_view.dart';
import 'package:rememberem/src/memories/crop_screen.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  late FakeDictation dictation;
  late Memory memory;
  const here = GeoPoint(47.6, -122.3);

  setUp(() async {
    repository = FakeMemoryRepository();
    dictation = FakeDictation();
    memory = await repository.add(photoJpeg: [], capturedAt: DateTime(2026));
  });

  Future<void> showCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryEditScreen(
          memory: repository.stored[memory.id]!,
          services: testServices(
            repository,
            dictation: dictation,
            location: FakeLocation(here),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> withDetails(List<Detail> details) =>
      repository.save(repository.stored[memory.id]!.withDetails(details));

  Detail fact(String id, String text) =>
      Detail(id: id, text: text, at: DateTime(2026), type: DetailKind.fact);

  group('detail box', () {
    testWidgets('closed: one line with only an expander, its label on the '
        'border even when empty', (tester) async {
      await withDetails([
        Detail(
          id: 'r',
          text: '',
          at: DateTime(2026),
          type: DetailKind.relationship,
          label: 'boss',
        ),
      ]);
      await showCard(tester);

      const label = 'Relationship · Boss';
      expect(find.byTooltip('Open $label'), findsOneWidget);
      expect(find.byTooltip('Speak $label'), findsNothing);
      expect(find.byTooltip('Delete $label'), findsNothing);
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, label),
      );
      expect(
        field.decoration!.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
    });

    testWidgets('tapping into it opens it with mic and delete; tapping '
        'outside closes it', (tester) async {
      await withDetails([fact('a', 'Tall')]);
      await showCard(tester);

      await tester.tap(find.widgetWithText(TextField, 'Tall'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Speak Fact'), findsOneWidget);
      expect(find.byTooltip('Delete Fact'), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.widgetWithText(TextField, 'Meeting')),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete Fact'), findsNothing);
      expect(find.byTooltip('Open Fact'), findsOneWidget);
    });

    testWidgets('the text selection toolbar does not close it', (
      tester,
    ) async {
      await withDetails([fact('a', 'Tall person')]);
      await showCard(tester);
      await tester.tap(find.byTooltip('Open Fact'));
      await tester.pumpAndSettle();

      await tester.longPress(find.widgetWithText(TextField, 'Tall person'));
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete Fact'), findsOneWidget);
    });

    testWidgets('stays open while dictating', (tester) async {
      await withDetails([fact('a', 'Tall')]);
      await showCard(tester);
      await tester.tap(find.byTooltip('Open Fact'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Speak Fact'));
      await tester.pump();

      await tester.tapAt(
        tester.getCenter(find.widgetWithText(TextField, 'Meeting')),
      );
      await tester.pump();
      expect(find.byTooltip('Stop listening'), findsOneWidget);
      dictation.say('and kind');
      dictation.goQuiet();
      await tester.pump(const Duration(seconds: 1));

      expect(
        repository.stored[memory.id]!.details.single.text,
        'Tall and kind',
      );
    });

    testWidgets('a date picker opened from inside does not close it', (
      tester,
    ) async {
      await withDetails([
        Detail(
          id: 'h',
          text: 'Picnic',
          at: DateTime(2026, 5, 3, 10),
          type: DetailKind.happening,
        ),
      ]);
      await showCard(tester);
      await tester.tap(find.byTooltip('Open Happening · 3 May 2026'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('When it happened'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete Happening · 3 May 2026'), findsOneWidget);
    });
  });

  testWidgets('choosing Who from the menu does not close a relationship', (
    tester,
  ) async {
    await repository.save(
      (await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 3),
      )).withField('name', 'Jill'),
    );
    await withDetails([
      Detail(
        id: 'r',
        text: 'Kind',
        at: DateTime(2026),
        type: DetailKind.relationship,
      ),
    ]);
    await showCard(tester);
    await tester.tap(find.byTooltip('Open Relationship'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jill').last);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete Relationship · Jill'), findsOneWidget);
  });

  testWidgets('trash tapped twice goes back once', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('list')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('middle')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryEditScreen(
          memory: repository.stored[memory.id]!,
          services: testServices(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Move to trash'));
    await tester.tap(find.byTooltip('Move to trash'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('middle'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('a happening place from the map', () {
    Future<void> openPlace(WidgetTester tester) async {
      await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 2),
        location: here,
        place: 'Cafe',
      );
      await withDetails([
        Detail(
          id: 'h',
          text: 'Picnic',
          at: DateTime(2026, 5, 3, 10),
          type: DetailKind.happening,
        ),
      ]);
      await showCard(tester);
      await tester.tap(find.byTooltip('Open Happening · 3 May 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose place'));
      await tester.pumpAndSettle();
    }

    testWidgets('a known place pin chooses it', (tester) async {
      await openPlace(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PlaceMarkerView),
          matching: find.text('Cafe'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.stored[memory.id]!.details.single.place, 'Cafe');
      expect(find.text('Happening · 3 May 2026 · Cafe'), findsOneWidget);
    });

    testWidgets('a spot is named by Fred, starting from the known place '
        'there', (tester) async {
      await openPlace(tester);
      await tester.tap(find.text('Use this spot'));
      await tester.pumpAndSettle();
      expect(find.text('Name this place'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cafe'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Back garden');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.stored[memory.id]!.details.single.place, 'Back garden');
    });
  });

  testWidgets('the crop page explains itself and crops only on Crop', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: CropScreen(jpeg: Uint8List(0))));
    await tester.pump();

    expect(
      find.text('Use pinch to zoom in or out, then press Crop'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Crop'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });

  group('about', () {
    testWidgets('the logo opens it; its links open in the browser', (
      tester,
    ) async {
      final links = FakeLinkOpener();
      await tester.pumpWidget(
        RememberemApp(services: testServices(repository, links: links)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('About'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.textContaining('Eric Jorgensen'), findsOneWidget);
      expect(find.textContaining('Suggestions are welcome'), findsOneWidget);

      await tester.tap(find.text('ericjorgensen.com'));
      await tester.tap(find.text('Suggest an idea or report a problem'));
      expect(links.opened, [
        Uri.parse('https://ericjorgensen.com'),
        Uri.parse('https://github.com/nebosite/rememberem/issues'),
      ]);
    });

    testWidgets('Settings links to it at the bottom', (tester) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RememberemApp(services: testServices(repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('About Rememberem'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
    });
  });
}
