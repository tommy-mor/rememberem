import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/maps/place_marker_view.dart';
import 'package:rememberem/src/places/place_row.dart';
import 'package:rememberem/src/places/places_screen.dart';
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
      capturedAt: DateTime(2026, 11, repository.stored.length % 28 + 1),
      location: at,
      place: place,
    );
    await repository.save(memory.withField('name', name));
  }

  Future<void> showPlaces(WidgetTester tester, double scale) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: PlacesScreen(
          services: testServices(repository),
          routeObserver: observer,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double rowHeight(WidgetTester tester) =>
      tester.getSize(find.byType(PlaceRow).first).height;

  for (final scale in [1.0, 2.0]) {
    group('at text scale $scale', () {
      testWidgets('a collapsed row is about collapsedExtent, scaled', (
        tester,
      ) async {
        await person('Alex', 'Cafe', north(0));
        await showPlaces(tester, scale);

        final estimate = PlaceRow.collapsedHeight(TextScaler.linear(scale));
        final measured = rowHeight(tester);
        // The estimate only has to land near: the row is then fully
        // scrolled into view from where it puts the list.
        expect(measured, closeTo(estimate, estimate * 0.05));
        if (scale == 1) {
          expect(measured, closeTo(PlaceRow.collapsedExtent, 1));
        }
      });

      for (final people in [1, 3]) {
        testWidgets('$people expanded people add about personExtent each', (
          tester,
        ) async {
          for (var i = 0; i < people; i++) {
            await person('Person $i', 'Cafe', north(0));
          }
          await showPlaces(tester, scale);
          final collapsed = rowHeight(tester);

          await tester.tap(find.byTooltip('Show the people met at Cafe'));
          await tester.pumpAndSettle();
          final added = (rowHeight(tester) - collapsed) / people;

          final estimate = PlaceRow.personHeight(TextScaler.linear(scale));
          expect(added, closeTo(estimate, estimate * 0.05));
          if (scale == 1) {
            expect(added, closeTo(PlaceRow.personExtent, 1));
          }
        });
      }

      testWidgets('with 12 places, the last one selected is scrolled fully '
          'into the list', (tester) async {
        for (var i = 1; i <= 12; i++) {
          // Names sort the rows newest first, so make the last one last.
          await person('Person $i', 'Place $i', north(i * 5));
        }
        await showPlaces(tester, scale);

        // Expand the second row, above the last.
        final second = find.byType(PlaceRow).at(1);
        final place = tester.widget<PlaceRow>(second).group.label;
        await tester.tap(find.byTooltip('Show the people met at $place'));
        await tester.pumpAndSettle();

        final last = _lastRowPlace(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(PlaceMarkerView),
            matching: find.text(last),
          ),
        );
        await tester.pump(kDoubleTapTimeout);
        await tester.pumpAndSettle();

        final row = find.byWidgetPredicate(
          (w) => w is PlaceRow && w.group.label == last,
        );
        expect(row, findsOneWidget);
        final list = tester.getRect(find.byType(ListView));
        final rect = tester.getRect(row);
        expect(rect.top, greaterThanOrEqualTo(list.top - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(list.bottom + 0.5));
      });
    });
  }
}

/// The label of the last place in the list (the oldest).
String _lastRowPlace(WidgetTester tester) {
  final rows = tester.widgetList<PlaceRow>(
    find.byType(PlaceRow, skipOffstage: false),
  );
  return rows.last.group.label;
}
