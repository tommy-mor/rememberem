import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory metAt(String id, String place, GeoPoint at) => Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2026),
      fields: {'name': id},
      location: at,
      place: place,
    );

void main() {
  group('RadiusScale', () {
    test('runs from 100 feet to 100 miles, evenly by ratio', () {
      expect(RadiusScale.metersAt(0), closeTo(30.48, 1e-9));
      expect(RadiusScale.metersAt(1), closeTo(160934.4, 1e-6));
      // Halfway is the geometric mean: about 2214 m.
      expect(RadiusScale.metersAt(0.5), closeTo(2214.8, 0.1));
      expect(RadiusScale.metersAt(-1), closeTo(30.48, 1e-9));
      expect(RadiusScale.metersAt(2), closeTo(160934.4, 1e-6));
    });

    test('a position and its radius round-trip', () {
      for (final t in [0.0, 0.2, 0.37, 0.8, 1.0]) {
        expect(
          RadiusScale.positionOf(RadiusScale.metersAt(t)),
          closeTo(t, 1e-9),
        );
      }
      expect(RadiusScale.positionOf(1), 0);
      expect(RadiusScale.positionOf(1e9), 1);
    });
  });

  group('Distance', () {
    test('feet and miles', () {
      expect(Distance.format(30.48, metric: false), '100 ft');
      expect(Distance.format(169.164, metric: false), '555 ft');
      expect(Distance.format(1931.2, metric: false), '1.2 mi');
      expect(Distance.format(24140, metric: false), '15 mi');
      expect(Distance.format(160934.4, metric: false), '100 mi');
    });

    test('metres and kilometres', () {
      expect(Distance.format(30.48, metric: true), '30 m');
      expect(Distance.format(169.164, metric: true), '170 m');
      expect(Distance.format(1500, metric: true), '1.5 km');
      expect(Distance.format(15000, metric: true), '15 km');
      expect(Distance.format(160934.4, metric: true), '161 km');
    });
  });

  group('AppSettings radii and units', () {
    test('metric unless the region uses feet and miles, or Fred chose', () {
      expect(AppSettings.metricByDefault('US'), isFalse);
      expect(AppSettings.metricByDefault('gb'), isFalse);
      expect(AppSettings.metricByDefault('DE'), isTrue);
      expect(AppSettings.metricByDefault(null), isTrue);
      expect(const AppSettings().metricFor('US'), isFalse);
      expect(const AppSettings(metricUnits: true).metricFor('US'), isTrue);
      expect(const AppSettings(metricUnits: false).metricFor('FR'), isFalse);
    });

    test('round-trip; older files have no radii and no choice', () {
      final s = const AppSettings()
          .withPlaceRadius(' Park ', 1000)
          .copyWith(metricUnits: true);
      expect(s.placeRadii, {'Park': 1000});
      expect(AppSettings.fromJson(s.toJson()), s);
      final old = AppSettings.fromJson({'sounds': false});
      expect(old.placeRadii, isEmpty);
      expect(old.metricUnits, isNull);
      expect(const AppSettings().toJson().containsKey('placeRadii'), isFalse);
    });

    test('damaged radii are dropped or clamped', () {
      final s = AppSettings.fromJson({
        'placeRadii': {
          'Park': 'far',
          '': 100,
          'Cafe': 5,
          'Town': 1e12,
          'Home': 200,
        },
        'metricUnits': 'yes',
      });
      expect(s.placeRadii, {
        'Cafe': RadiusScale.minMeters,
        'Town': RadiusScale.maxMeters,
        'Home': 200,
      });
      expect(s.metricUnits, isNull);
      expect(
          AppSettings.fromJson({
            'placeRadii': [1, 2]
          }).placeRadii,
          isEmpty);
    });

    test('a place uses its own radius, else the default', () {
      final s =
          const AppSettings(placeRadiusFeet: 500).withPlaceRadius('Park', 2000);
      expect(s.radiusFor(' Park'), 2000);
      expect(s.radiusFor('park'), closeTo(152.4, 1e-9)); // case is kept
      expect(s.withPlaceRadius('Park', null).radiusFor('Park'),
          closeTo(152.4, 1e-9));
      expect(s, isNot(const AppSettings(placeRadiusFeet: 500)));
      expect(
        s,
        const AppSettings(placeRadiusFeet: 500).withPlaceRadius('Park', 2000),
      );
      expect(
        s.hashCode,
        const AppSettings(placeRadiusFeet: 500)
            .withPlaceRadius('Park', 2000)
            .hashCode,
      );
    });

    test('a set radius is clamped to the slider; units count in ==', () {
      final s =
          const AppSettings().withPlaceRadius('A', 1).withPlaceRadius('B', 1e9);
      expect(s.placeRadii, {
        'A': RadiusScale.minMeters,
        'B': RadiusScale.maxMeters,
      });
      expect(
        const AppSettings(metricUnits: true),
        isNot(const AppSettings(metricUnits: false)),
      );
      expect(const AppSettings(metricUnits: true),
          const AppSettings(metricUnits: true));
    });

    test('a renamed place keeps its radius; a merge keeps the target one', () {
      final s = const AppSettings()
          .withPlaceRadius('Park', 2000)
          .withPlaceRadius('Cafe', 300);
      expect(s.withPlaceRenamed('Park', 'City Park').placeRadii, {
        'City Park': 2000,
        'Cafe': 300,
      });
      expect(s.withPlaceRenamed('Park', 'Cafe').placeRadii, {'Cafe': 300});
      expect(s.withPlaceRenamed('Gym', 'Pool'), s);
    });
  });

  group('PlaceFinder with radii', () {
    const park = GeoPoint(47.0, -122.0);
    // About 1.1 km north of the park.
    const north = GeoPoint(47.01, -122.0);

    test('a big radius reaches further; a small one less', () {
      final people = [metAt('a', 'Park', park)];
      const plain = PlaceFinder(radiusMeters: 169.164);
      expect(plain.nearest(north, people), isNull);

      const wide = PlaceFinder(radiusMeters: 169.164, radii: {'Park': 2000});
      expect(wide.nearest(north, people)?.place, 'Park');

      const tight = PlaceFinder(radiusMeters: 169.164, radii: {'Park': 50});
      expect(tight.nearest(const GeoPoint(47.001, -122.0), people), isNull);
    });

    test('the nearest place whose own radius reaches wins', () {
      final people = [
        metAt('a', 'Town', const GeoPoint(47.02, -122.0)),
        metAt('b', 'Park', park),
      ];
      const finder = PlaceFinder(
        radiusMeters: 100,
        radii: {'Town': 5000},
      );
      // The park is nearer but its radius does not reach.
      expect(finder.nearest(north, people)?.place, 'Town');
    });
  });
}
