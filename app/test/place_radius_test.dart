import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/maps/location_picker_screen.dart';
import 'package:rememberem/src/places/place_row.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem/src/places/radius_slider.dart';
import 'package:rememberem/src/settings/settings_screen.dart';
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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> showPlaces(WidgetTester tester) async {
    phone(tester);
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: PlacesScreen(services: services, routeObserver: observer),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<CircleMarker> circles(WidgetTester tester) =>
      tester.widget<CircleLayer>(find.byType(CircleLayer)).circles;

  Finder radiusButton(String text) => find.descendant(
    of: find.byType(PlaceRow),
    matching: find.widgetWithText(TextButton, text),
  );

  setUp(() {
    repository = FakeMemoryRepository();
    services = testServices(repository);
  });

  testWidgets('each named place shows its radius, in the chosen units, and '
      'a circle on the map', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(5));
    await person('Lee', '', north(10));
    services.settings.value = services.settings.value.withPlaceRadius(
      'Park',
      1609.344,
    );
    await showPlaces(tester);

    expect(radiusButton('555 ft'), findsOneWidget);
    expect(radiusButton('1.0 mi'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(2)); // not the unknown
    expect(circles(tester).map((c) => c.radius).toList()..sort(), [
      closeTo(169.164, 1e-6),
      closeTo(1609.344, 1e-6),
    ]);
    expect(circles(tester).every((c) => c.useRadiusInMeter), isTrue);

    services.settings.value = services.settings.value.copyWith(
      metricUnits: true,
    );
    await tester.pumpAndSettle();
    expect(radiusButton('170 m'), findsOneWidget);
    expect(radiusButton('1.6 km'), findsOneWidget);
  });

  testWidgets('the radius slides on its row: the circle moves as it '
      'slides, saves on release, and a tap elsewhere ends it', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);

    await tester.tap(radiusButton('555 ft'));
    await tester.pump(); // not settle: the slider pulses
    final slider = find.descendant(
      of: find.byType(PlaceRow),
      matching: find.byType(RadiusSlider),
    );
    expect(slider, findsOneWidget);
    expect(radiusButton('555 ft'), findsNothing); // the slider replaced it

    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    final dragged = circles(tester).single.radius;
    expect(dragged, greaterThan(500)); // from 169 m
    expect(services.settings.value.placeRadii, isEmpty); // not yet

    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(circles(tester).single.radius, greaterThan(dragged)); // live

    await gesture.up();
    await tester.pump();
    final saved = services.settings.value.placeRadii['Cafe'];
    expect(saved, isNotNull);
    expect(circles(tester).single.radius, saved);

    await tester.tap(find.byTooltip('Smaller'));
    await tester.pump();
    expect(services.settings.value.placeRadii['Cafe'], lessThan(saved!));

    // Tapping elsewhere ends sliding.
    await tester.tapAt(const Offset(540, 2300));
    await tester.pumpAndSettle();
    expect(find.byType(RadiusSlider), findsNothing);
  });

  testWidgets('stepping back to the default radius ends the own radius', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);
    await tester.tap(radiusButton('555 ft'));
    await tester.pump();

    await tester.tap(find.byTooltip('Larger'));
    await tester.pump();
    expect(services.settings.value.placeRadii, isNotEmpty);
    await tester.tap(find.byTooltip('Smaller'));
    await tester.pump();
    expect(services.settings.value.placeRadii, isEmpty);
  });

  testWidgets('a renamed place keeps its radius', (tester) async {
    await person('Alex', 'Cafe', north(0));
    services.settings.value = services.settings.value.withPlaceRadius(
      'Cafe',
      500,
    );
    await showPlaces(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Cafe'), 'Diner');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(services.settings.value.placeRadii, {'Diner': 500});
  });

  testWidgets('the check button saves a name too', (tester) async {
    final kim = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
      location: north(0),
    );
    await showPlaces(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceRow),
        matching: find.byType(TextField),
      ),
      'Gym',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Save the name'));
    await tester.pumpAndSettle();

    expect(repository.stored[kim.id]!.latest.place, 'Gym');
  });

  testWidgets('naming a place drops a radius left from a place now gone', (
    tester,
  ) async {
    await person('Alex', '', north(0));
    services.settings.value = services.settings.value.withPlaceRadius(
      'Gym',
      5000,
    );
    await showPlaces(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceRow),
        matching: find.byType(TextField),
      ),
      'Gym',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(services.settings.value.placeRadii, isEmpty);
    expect(radiusButton('555 ft'), findsOneWidget);
  });

  testWidgets('outside the US, metres by default', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await person('Alex', 'Cafe', north(0));
    await showPlaces(tester);

    expect(radiusButton('170 m'), findsOneWidget);
  });

  testWidgets('the location picker draws known places with their radius', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPickerScreen(services: services, initial: north(0)),
      ),
    );
    await tester.pumpAndSettle();

    expect(circles(tester).single.radius, closeTo(169.164, 1e-6));
  });

  testWidgets('Settings switches units, and the default radius shows in '
      'them', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: services.settings,
          links: services.links,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('555 ft'), findsOneWidget);

    final toggle = find.widgetWithText(SwitchListTile, 'Metric units (m, km)');
    await tester.scrollUntilVisible(toggle, 200);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse); // en_US
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(services.settings.value.metricUnits, isTrue);
    await tester.scrollUntilVisible(find.text('170 m'), -200);
    expect(find.text('170 m'), findsOneWidget);
  });
}
