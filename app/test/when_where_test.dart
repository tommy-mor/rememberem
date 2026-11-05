import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/maps/location_picker_screen.dart';
import 'package:rememberem/src/maps/place_marker_view.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  const here = GeoPoint(47.6, -122.3);

  setUp(() => repository = FakeMemoryRepository());

  Future<Memory> showCard(
    WidgetTester tester, {
    GeoPoint? location,
    GeoPoint? deviceAt,
    String place = '',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 3, 15),
      location: location,
      place: place,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MemoryEditScreen(
          memory: memory,
          services: testServices(repository, location: FakeLocation(deviceAt)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return memory;
  }

  Encounter stored(Memory m) => repository.stored[m.id]!.encounters.first;

  testWidgets('the pin opens the picker at where the phone is, marking '
      'known places; Use saves that spot', (tester) async {
    final cafe = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, 1),
      location: const GeoPoint(47.61, -122.31),
      place: 'Cafe',
    );
    final memory = await showCard(tester, deviceAt: here);
    expect(find.text('No location'), findsOneWidget);

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    expect(find.byType(LocationPickerScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlaceMarkerView),
        matching: find.text('Cafe'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Use this spot'));
    await tester.pumpAndSettle();

    expect(stored(memory).location!.latitude, closeTo(here.latitude, 1e-6));
    expect(stored(memory).location!.longitude, closeTo(here.longitude, 1e-6));
    // Two decimals; the Cafe is over a kilometre away, so no place name.
    expect(find.text('47.60, -122.30'), findsOneWidget);
    expect(stored(memory).place, isEmpty);
    expect(repository.stored[cafe.id]!.encounters.first.place, 'Cafe');
  });

  testWidgets('a spot near a known place takes its name, over a typed one', (
    tester,
  ) async {
    await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, 1),
      location: const GeoPoint(47.6001, -122.3001),
      place: 'Cafe',
    );
    final memory = await showCard(
      tester,
      place: 'Typed by hand',
      deviceAt: here,
    );

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this spot'));
    await tester.pumpAndSettle();

    expect(stored(memory).place, 'Cafe');
    expect(find.widgetWithText(TextField, 'Cafe'), findsOneWidget);
  });

  testWidgets('tapping a known place pin chooses that place', (tester) async {
    await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 10, 1),
      location: here,
      place: 'Cafe',
    );
    final memory = await showCard(tester, deviceAt: here);

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PlaceMarkerView),
        matching: find.text('Cafe'),
      ),
    );
    await tester.pumpAndSettle();

    expect(stored(memory).location, here);
    expect(stored(memory).place, 'Cafe');
  });

  testWidgets('with no match the Place field is blank and hints unknown', (
    tester,
  ) async {
    final memory = await showCard(tester, place: 'Typed', deviceAt: here);
    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this spot'));
    await tester.pumpAndSettle();

    expect(stored(memory).place, isEmpty);
    final place = tester.widget<TextField>(
      find.widgetWithText(TextField, 'PLACE'),
    );
    expect(place.decoration!.hintText, 'unknown');
  });

  testWidgets('Remote clears the location and sets the place, on the card '
      'and in the Place field', (tester) async {
    final memory = await showCard(tester, location: here, place: 'Office');

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remote'));
    await tester.pumpAndSettle();

    expect(stored(memory).location, isNull);
    expect(stored(memory).place, Encounter.remotePlace);
    expect(find.widgetWithText(TextField, 'Remote'), findsOneWidget);
  });

  testWidgets('Back from the picker changes nothing', (tester) async {
    final memory = await showCard(tester, location: here, place: 'Office');

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(stored(memory).location, here);
    expect(stored(memory).place, 'Office');
  });

  testWidgets('the clock changes the picture date and time', (tester) async {
    final memory = await showCard(tester);

    await tester.tap(find.byTooltip('Change date and time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('17'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(stored(memory).capturedAt, DateTime(2026, 11, 17, 15));
  });

  testWidgets('a person with no name shows as Unknown; the field hints it', (
    tester,
  ) async {
    await repository.add(photoJpeg: [], capturedAt: DateTime(2026, 11, 1));
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: MemoryListScreen(
          services: testServices(repository),
          routeObserver: observer,
          onMeetSomeone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unknown'), findsOneWidget);

    await tester.tap(find.text('Unknown'));
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(
      find.widgetWithText(TextField, 'NAME'),
    );
    expect(name.decoration!.hintText, 'Unknown');
    expect(name.controller!.text, isEmpty);
  });

  testWidgets('a real spot after Remote clears the Remote place', (
    tester,
  ) async {
    final memory = await showCard(tester, deviceAt: here);
    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remote'));
    await tester.pumpAndSettle();
    expect(stored(memory).place, Encounter.remotePlace);

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this spot'));
    await tester.pumpAndSettle();

    expect(stored(memory).location, here);
    expect(stored(memory).place, isEmpty);
    expect(find.widgetWithText(TextField, 'Remote'), findsNothing);
  });
}
