import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

/// A point [meters] north of [from] (1 degree of latitude ~ 111,195 m).
GeoPoint north(GeoPoint from, double meters) =>
    GeoPoint(from.latitude + meters / 111194.93, from.longitude);

Memory at(String place, GeoPoint? location,
        {DateTime? when, String id = 'p'}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id-$place.jpg',
      capturedAt: when ?? DateTime.utc(2026, 1, 1),
      location: location,
      place: place,
    );

void main() {
  const finder = PlaceFinder();
  const here = GeoPoint(0, 0);

  group('GeoPoint.distanceTo', () {
    test('one degree of latitude is about 111.2 km', () {
      expect(here.distanceTo(const GeoPoint(1, 0)), closeTo(111195, 10));
    });

    test('the same point is 0 m away', () {
      expect(here.distanceTo(here), 0);
    });

    test('works across the antimeridian', () {
      expect(
        const GeoPoint(0, 179.9999).distanceTo(const GeoPoint(0, -179.9999)),
        closeTo(22.2, 0.5),
      );
    });

    test('a NaN coordinate gives NaN', () {
      expect(here.distanceTo(const GeoPoint(double.nan, 0)).isNaN, isTrue);
    });
  });

  test('a place 91 m away counts and one 92 m away does not', () {
    expect(
        finder.nearest(here, [at('Near', north(here, 91.0))])?.place, 'Near');
    expect(finder.nearest(here, [at('Far', north(here, 92.0))]), isNull);
  });

  test('the radius holds east-west at high latitude too', () {
    const oslo = GeoPoint(60, 10);
    // At 60 degrees north a degree of longitude is half as long.
    final east91 = GeoPoint(60, 10 + 91.0 / (111194.93 * 0.5));
    final east92 = GeoPoint(60, 10 + 92.0 / (111194.93 * 0.5));
    expect(finder.nearest(oslo, [at('Cafe', east91)])?.place, 'Cafe');
    expect(finder.nearest(oslo, [at('Cafe', east92)]), isNull);
  });

  test('the closest place wins whatever the order', () {
    final near = at('Near', north(here, 30), id: 'a');
    final far = at('Far', north(here, 60), id: 'b');

    expect(finder.nearest(here, [near, far])?.place, 'Near');
    expect(finder.nearest(here, [far, near])?.place, 'Near');
  });

  test('equal distances go to the newest encounter in either order', () {
    final older = at('Old', north(here, 30), when: DateTime.utc(2025), id: 'a');
    final newer = at('New', north(here, 30), when: DateTime.utc(2026), id: 'b');

    expect(finder.nearest(here, [older, newer])?.place, 'New');
    expect(finder.nearest(here, [newer, older])?.place, 'New');
  });

  test('blank places and missing locations are ignored even when closest', () {
    final people = [
      at('  ', north(here, 5), id: 'a'),
      at('Nowhere', null, id: 'b'),
      at('Real', north(here, 50), id: 'c'),
    ];

    expect(finder.nearest(here, people)?.place, 'Real');
  });

  test('every encounter counts, not only the newest', () {
    final memory = Memory(
      id: 'p',
      encounters: [
        Encounter(
          photoFileName: 'new.jpg',
          capturedAt: DateTime.utc(2026),
          location: const GeoPoint(10, 10),
          place: 'Far away',
        ),
        Encounter(
          photoFileName: 'old.jpg',
          capturedAt: DateTime.utc(2025),
          location: north(here, 20),
          place: 'Here',
        ),
      ],
    );

    expect(finder.nearest(here, [memory])?.place, 'Here');
  });

  test('a legacy record with place and location is a known place', () {
    final legacy = Memory.fromJson({
      'id': 'old',
      'photo': 'old.jpg',
      'capturedAt': '2026-01-01T00:00:00.000',
      'location': {'latitude': 0.0001, 'longitude': 0},
      'fields': {'place': 'Stake Center'},
    });

    expect(finder.nearest(here, [legacy])?.place, 'Stake Center');
  });

  test('NaN coordinates never match', () {
    expect(finder.nearest(here, [at('Bad', const GeoPoint(double.nan, 0))]),
        isNull);
    expect(
        finder.nearest(
            const GeoPoint(double.nan, 0), [at('Cafe', north(here, 10))]),
        isNull);
  });
}
