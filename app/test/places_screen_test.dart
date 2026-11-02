import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/places/place_map_projection.dart';
import 'package:rememberem/src/places/places_map.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

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
        home: PlacesScreen(repository: repository, routeObserver: observer),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the map dot drawn for [point].
  Future<void> tapMarker(
    WidgetTester tester,
    List<GeoPoint> drawn,
    GeoPoint point,
  ) async {
    final map = find.byType(PlacesMap);
    final box = tester.getRect(map);
    final projection = PlaceMapProjection(drawn, box.size);
    await tester.tapAt(box.topLeft + projection.project(point));
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

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Kim'), findsNothing);
    },
  );

  testWidgets('tapping a marker selects that place', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(5));
    await showPlaces(tester);

    await tapMarker(tester, [north(0), north(5)], north(5));

    expect(find.text('Kim'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('a place with no location is listed without a marker', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    await person('Nomad', 'Somewhere', null);
    await showPlaces(tester);

    expect(find.text('Somewhere'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget); // no marker
  });

  testWidgets('renaming a place updates the list and the people', (
    tester,
  ) async {
    final alex = await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);

    await tester.tap(find.byTooltip('Rename Cafe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cafe'), 'Diner');
    await tester.tap(find.text('Save'));
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

    await tester.tap(find.byTooltip('Rename Cafe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cafe'), 'Diner');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not rename the place. Try again.'), findsOneWidget);
    expect(find.text('Cafe'), findsWidgets);
    expect(find.text('Diner'), findsNothing);
    expect(repository.stored.values.single.latest.place, 'Cafe');
  });

  testWidgets('selecting the last of many places brings its row into view', (
    tester,
  ) async {
    final drawn = <GeoPoint>[];
    for (var i = 0; i < 30; i++) {
      final at = north(i * 1.0);
      drawn.add(at);
      await person('P$i', 'Place ${i.toString().padLeft(2, '0')}', at);
    }
    await showPlaces(tester);
    expect(find.text('P29'), findsNothing);

    await tapMarker(tester, drawn, drawn.last);

    expect(find.text('P29').hitTestable(), findsOneWidget);
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

    await tester.tap(find.byTooltip('Rename Park'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Park'), 'Cafe');
    await tester.pump();

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

    expect(find.text('Cafe'), findsOneWidget);
  });

  testWidgets('cancelling a rename keeps an unknown place expanded', (
    tester,
  ) async {
    await person('Kim', '', north(0));
    await showPlaces(tester);
    await tester.tap(find.text('unknown'));
    await tester.pumpAndSettle();
    expect(find.text('Kim'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename unknown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Kim'), findsOneWidget);
  });

  testWidgets('at double text size the selected row still comes into view', (
    tester,
  ) async {
    final drawn = <GeoPoint>[];
    for (var i = 0; i < 30; i++) {
      final at = north(i * 1.0);
      drawn.add(at);
      await person('P$i', 'Place ${i.toString().padLeft(2, '0')}', at);
    }
    await showPlaces(tester, textScale: 2);

    await tapMarker(tester, drawn, drawn.last);

    expect(find.text('P29').hitTestable(), findsOneWidget);
  });
}
