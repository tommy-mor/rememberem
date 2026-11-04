import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/maps/place_marker_view.dart';
import 'package:rememberem/src/maps/street_map.dart';
import 'package:rememberem/src/places/places_map.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

GeoPoint north(double km) => GeoPoint(km / 111.19493, 0);

void main() {
  late FakeMemoryRepository repository;
  late AppServices services;

  Future<void> person(String name, String place, GeoPoint at) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, repository.stored.length + 1),
      location: at,
      place: place,
    );
    await repository.save(m.withField('name', name));
  }

  Future<void> showPlaces(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: PlacesScreen(services: services, routeObserver: observer),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder marker(String label) => find.descendant(
    of: find.byType(PlaceMarkerView),
    matching: find.text(label),
  );

  MapCamera camera(WidgetTester tester) =>
      MapCamera.of(tester.element(find.byType(MarkerLayer)));

  List<Marker> markers(WidgetTester tester) =>
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;

  setUp(() async {
    repository = FakeMemoryRepository();
    services = testServices(repository);
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(1));
    await person('Sam', '', north(3));
  });

  testWidgets('selecting a place draws it on top and centres on it', (
    tester,
  ) async {
    await showPlaces(tester);
    await tester.tap(find.text('Cafe').first);
    await tester.pumpAndSettle();

    expect(markers(tester).last.point, StreetMap.latLng(north(0)));
    final map = tester.widget<PlacesMap>(find.byType(PlacesMap));
    expect(map.selected?.name, 'Cafe');
    final tick = map.centreTick;

    // Choosing it again centres again.
    await tester.tap(find.text('Cafe').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlacesMap>(find.byType(PlacesMap)).centreTick,
      greaterThan(tick),
    );
  });

  testWidgets('a double tap zooms so the radius is a fifth of the map, '
      'every time', (tester) async {
    await showPlaces(tester);
    Future<void> doubleTap() async {
      await tester.tap(marker('Park'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(marker('Park'));
      await tester.pumpAndSettle();
    }

    double shorterSideMeters() {
      final bounds = camera(tester).visibleBounds;
      final ns = GeoPoint(
        bounds.south,
        bounds.west,
      ).distanceTo(GeoPoint(bounds.north, bounds.west));
      final ew = GeoPoint(
        bounds.south,
        bounds.west,
      ).distanceTo(GeoPoint(bounds.south, bounds.east));
      return ns < ew ? ns : ew;
    }

    await doubleTap();
    const radius = 169.164;
    expect(radius / shorterSideMeters(), closeTo(0.2, 0.01));
    final zoomed = camera(tester).zoom;

    // Zoom out by hand, then double-tap again: back to the same fit.
    await tester.drag(find.byType(FlutterMap), const Offset(0, 200));
    await tester.pumpAndSettle();
    final controller = MapController.maybeOf(
      tester.element(find.byType(MarkerLayer)),
    )!;
    controller.move(controller.camera.center, zoomed - 3);
    await tester.pumpAndSettle();
    await doubleTap();
    expect(camera(tester).zoom, closeTo(zoomed, 0.01));
  });

  testWidgets('a long press moves a place: drag the map, then Move here', (
    tester,
  ) async {
    await showPlaces(tester);
    await tester.longPress(marker('Cafe'));
    await tester.pumpAndSettle();
    expect(find.text('Drag the map to move Cafe'), findsOneWidget);
    expect(marker('Cafe'), findsNothing); // drawn by the fixed pin instead

    await tester.drag(find.byType(FlutterMap), const Offset(0, 300));
    await tester.pumpAndSettle();
    final centre = camera(tester).center;
    await tester.tap(find.text('Move here'));
    await tester.pumpAndSettle();

    final spot = services.settings.value.placeSpots['Cafe'];
    expect(spot, isNotNull);
    expect(spot!.latitude, closeTo(centre.latitude, 1e-9));
    expect(spot.longitude, closeTo(centre.longitude, 1e-9));
    expect(find.text('Drag the map to move Cafe'), findsNothing);
    // The photos keep their own location.
    expect(
      repository.stored.values
          .firstWhere((m) => m.latest.place == 'Cafe')
          .latest
          .location,
      north(0),
    );
    // The place is now drawn at its spot.
    expect(
      markers(tester).map((m) => m.point),
      contains(StreetMap.latLng(spot)),
    );
  });

  testWidgets('while moving, other places cannot be selected, so the spot '
      'stays where Fred dragged it', (tester) async {
    await showPlaces(tester);
    await tester.longPress(marker('Cafe'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(FlutterMap), const Offset(0, 300));
    await tester.pumpAndSettle();
    final centre = camera(tester).center;

    await tester.tap(find.text('Park').first); // its row
    await tester.pumpAndSettle();
    expect(camera(tester).center, centre);
    await tester.tap(find.text('Move here'));
    await tester.pumpAndSettle();
    expect(
      services.settings.value.placeSpots['Cafe']!.latitude,
      closeTo(centre.latitude, 1e-9),
    );
  });

  testWidgets('Move here without dragging keeps nothing', (tester) async {
    await showPlaces(tester);
    await tester.longPress(marker('Cafe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move here'));
    await tester.pumpAndSettle();
    expect(services.settings.value.placeSpots, isEmpty);
  });

  testWidgets('Cancel leaves the place where it was', (tester) async {
    await showPlaces(tester);
    await tester.longPress(marker('Cafe'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(FlutterMap), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(services.settings.value.placeSpots, isEmpty);
    expect(marker('Cafe'), findsOneWidget);
  });

  testWidgets('an unknown place cannot be moved; named ones offer zoom and '
      'move to a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await showPlaces(tester);

    await tester.longPress(marker('unknown'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Drag the map'), findsNothing);

    final views = tester.widgetList<PlaceMarkerView>(
      find.byType(PlaceMarkerView),
    );
    final cafe = views.firstWhere((v) => v.label == 'Cafe');
    final unknown = views.firstWhere((v) => v.label == 'unknown');
    expect(cafe.onDoubleTap, isNotNull);
    expect(cafe.onLongPress, isNotNull);
    expect(unknown.onLongPress, isNull);
    final node = tester.getSemantics(marker('Cafe'));
    expect(node.getSemanticsData().customSemanticsActionIds, hasLength(2));
    semantics.dispose();
  });

  testWidgets('a single tap on a marker still selects it', (tester) async {
    await showPlaces(tester);
    await tester.tap(marker('Park'));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlacesMap>(find.byType(PlacesMap)).selected?.name,
      'Park',
    );
  });
}
