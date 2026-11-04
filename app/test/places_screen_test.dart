import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rememberem/src/maps/place_marker_view.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/places/place_row.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

class _FailingSaves extends FakeMemoryRepository {
  bool fail = false;

  @override
  Future<void> save(Memory memory) {
    if (fail) throw const FileSystemException('disk full');
    return super.save(memory);
  }
}

GeoPoint north(double km) => GeoPoint(km / 111.19493, 0);

void main() {
  late FakeMemoryRepository repository;

  Future<Memory> person(String name, String place, GeoPoint? location) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, repository.stored.length + 1),
      location: location,
      place: place,
    );
    final named = memory.withField('name', name);
    await repository.save(named);
    return named;
  }

  late GlobalKey<NavigatorState> navigator;

  Future<void> showPlaces(WidgetTester tester, {double textScale = 1}) async {
    navigator = GlobalKey<NavigatorState>();
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: PlacesScreen(
          services: testServices(repository),
          routeObserver: observer,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the map marker labelled [label].
  Future<void> tapMarker(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PlaceMarkerView),
        matching: find.text(label),
      ),
    );
    // A single tap counts once a double tap can no longer follow.
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
  }

  /// [name] in the list (not on the map).
  Finder inList(String name) =>
      find.descendant(of: find.byType(PlaceRow), matching: find.text(name));

  /// Types [to] into the name of the place called [from] and presses Done.
  Future<void> renameInList(WidgetTester tester, String from, String to) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceRow),
        matching: find.widgetWithText(TextField, from),
      ),
      to,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  setUp(() => repository = FakeMemoryRepository());

  testWidgets(
    'lists named places and unknown ones; a row tap shows its people',
    (tester) async {
      await person('Alex', 'Cafe', north(0));
      await person('Sam', 'Cafe', north(0.01));
      await person('Kim', '', north(5));
      await showPlaces(tester);

      expect(find.text('Cafe'), findsWidgets); // row and map label
      expect(find.text('unknown'), findsWidgets);
      expect(find.text('Alex'), findsNothing);

      await tester.tap(find.textContaining('2 people'));
      await tester.pumpAndSettle();

      expect(inList('Alex'), findsOneWidget);
      expect(inList('Sam'), findsOneWidget);
      expect(find.text('Kim'), findsNothing);
    },
  );

  testWidgets('tapping a marker selects that place', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(5));
    await showPlaces(tester);

    await tapMarker(tester, 'Park');

    expect(inList('Kim'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('a place with no location is listed without a marker', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    await person('Nomad', 'Somewhere', null);
    await showPlaces(tester);

    expect(inList('Somewhere'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget); // no marker
  });

  testWidgets('renaming a place updates the list and the people', (
    tester,
  ) async {
    final alex = await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);

    await renameInList(tester, 'Cafe', 'Diner');
    expect(find.text('Rename "Cafe" to "Diner"?'), findsOneWidget);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Diner'), findsWidgets);
    expect(find.text('Cafe'), findsNothing);
    expect(repository.stored[alex.id]!.latest.place, 'Diner');
  });

  testWidgets('a failed rename says so and keeps the old name', (tester) async {
    repository = _FailingSaves();
    await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);
    (repository as _FailingSaves).fail = true;

    await renameInList(tester, 'Cafe', 'Diner');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Could not rename the place. Try again.'), findsOneWidget);
    expect(find.text('Cafe'), findsWidgets);
    expect(find.text('Diner'), findsNothing);
    expect(repository.stored.values.single.latest.place, 'Cafe');
  });

  testWidgets('selecting the last of many places brings its row into view', (
    tester,
  ) async {
    for (var i = 0; i < 30; i++) {
      await person(
        'P$i',
        'Place ${i.toString().padLeft(2, '0')}',
        north(i * 1.0),
      );
    }
    await showPlaces(tester);
    expect(find.text('P29'), findsNothing);

    await tapMarker(tester, 'Place 29');

    expect(inList('P29').hitTestable(), findsOneWidget);
  });

  testWidgets('the main list has a Places entry that opens the page', (
    tester,
  ) async {
    final observer = RouteObserver<ModalRoute<void>>();
    final services = AppServices(
      repository: repository,
      capture: PortraitCapture(
        repository: repository,
        faceLocator: _NoFaces(),
        workFolder: Directory.systemTemp,
      ),
      dictation: FakeDictation(),
      location: DeviceLocation(),
    );
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
    await tester.pump();

    await tester.tap(find.byTooltip('Places'));
    await tester.pumpAndSettle();

    expect(find.byType(PlacesScreen), findsOneWidget);
  });

  testWidgets('renaming to an existing name warns that the places merge', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(5));
    await showPlaces(tester);

    await renameInList(tester, 'Park', 'Cafe');

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.text('Changes 1 person.'), findsOneWidget);
  });

  testWidgets('a person restored elsewhere shows when Fred comes back', (
    tester,
  ) async {
    final kim = await person('Kim', 'Cafe', north(0));
    await repository.trash(kim.id, DateTime(2026, 12, 1));
    await person('Alex', 'Park', north(5));
    await showPlaces(tester);
    expect(find.text('Cafe'), findsNothing);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    await repository.restore(kim.id);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(inList('Cafe'), findsOneWidget);
  });

  testWidgets('an unknown place is named without asking, and stays '
      'expanded', (tester) async {
    final kim = await person('Kim', '', north(0));
    await showPlaces(tester);
    await tester.tap(inList('unknown'));
    await tester.pumpAndSettle();
    expect(inList('Kim'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceRow),
        matching: find.byType(TextField),
      ),
      'Gym',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.stored[kim.id]!.latest.place, 'Gym');
    expect(inList('Gym'), findsOneWidget);
  });

  testWidgets('Cancel, or leaving the field, keeps a known name', (
    tester,
  ) async {
    final alex = await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(5));
    await showPlaces(tester);

    await renameInList(tester, 'Cafe', 'Diner');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(inList('Cafe'), findsOneWidget);
    expect(repository.stored[alex.id]!.latest.place, 'Cafe');

    // Typing, then tapping another place, renames nothing.
    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceRow),
        matching: find.widgetWithText(TextField, 'Cafe'),
      ),
      'Diner',
    );
    await tester.pump();
    expect(find.byTooltip('Save the name'), findsOneWidget);
    await tester.tap(find.textContaining('1 person').last);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(inList('Cafe'), findsOneWidget);
    expect(inList('Diner'), findsNothing);
  });

  testWidgets('at double text size the selected row still comes into view', (
    tester,
  ) async {
    for (var i = 0; i < 30; i++) {
      await person(
        'P$i',
        'Place ${i.toString().padLeft(2, '0')}',
        north(i * 1.0),
      );
    }
    await showPlaces(tester, textScale: 2);

    await tapMarker(tester, 'Place 29');

    expect(inList('P29').hitTestable(), findsOneWidget);
  });

  testWidgets('a selected place lists its people with photos, only in the '
      'list; a tap opens their card and Back keeps the place', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(5));
    await showPlaces(tester);

    await tapMarker(tester, 'Cafe');
    expect(find.widgetWithText(ActionChip, 'Alex'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Alex'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditScreen), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(inList('Alex'), findsOneWidget);
  });

  testWidgets('with street maps off no tiles are fetched', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
  });
}
