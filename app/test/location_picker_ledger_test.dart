import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/maps/location_picker_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

GeoPoint north(double km) => GeoPoint(km / 111.19493, 0);

void main() {
  late FakeMemoryRepository repository;

  setUp(() => repository = FakeMemoryRepository());

  Future<void> person(String name, String place, GeoPoint at) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 3),
      location: at,
      place: place,
    );
    await repository.save(memory.withField('name', name));
  }

  Future<void> show(WidgetTester tester, {GeoPoint? initial}) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPickerScreen(
          services: testServices(repository),
          initial: initial,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder strip(String place) => find.ancestor(
    of: find.text(place),
    matching: find.byWidgetPredicate(
      (w) => w is ConstrainedBox && w.constraints.minHeight == 58,
    ),
  );

  testWidgets('the strip names the known place at the start, 58 dp tall', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    await show(tester, initial: north(0));

    expect(strip('Cafe'), findsWidgets);
    expect(
      tester.getSize(strip('Cafe').first).height,
      greaterThanOrEqualTo(58),
    );
  });

  testWidgets('there is no strip where no known place is', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await show(tester, initial: north(40));

    // "Cafe" is only in the list above the map.
    expect(strip('Cafe'), findsNothing);
  });

  testWidgets('tapping a listed place fills its radio and the strip', (
    tester,
  ) async {
    await person('Alex', 'Cafe', north(0));
    await person('Kim', 'Park', north(40));
    await show(tester, initial: north(80));
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Park'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    expect(strip('Park'), findsWidgets);
  });

  testWidgets('the list rows are at least 48 dp tall', (tester) async {
    await person('Alex', 'Cafe', north(0));
    await show(tester, initial: north(0));

    expect(
      tester.getSize(find.widgetWithText(ListTile, 'Cafe')).height,
      greaterThanOrEqualTo(48),
    );
  });
}
