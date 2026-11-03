import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

/// [meters] north of the equator at longitude 0.
GeoPoint north(double meters) => GeoPoint(meters / 111194.93, 0);

Encounter at(String photo, String place, GeoPoint? location, {int day = 1}) =>
    Encounter(
      photoFileName: photo,
      capturedAt: DateTime.utc(2026, 1, day),
      location: location,
      place: place,
    );

Memory person(String id, List<Encounter> encounters) =>
    Memory(id: id, encounters: encounters);

const on = AppSettings(placeAlerts: true);

List<String> names(List<PlaceFence> fences) => [for (final f in fences) f.name];

void main() {
  group('settings', () {
    test('place notifications start off with no choices', () {
      const s = AppSettings();
      expect(s.placeAlerts, isFalse);
      expect(s.placeAlertChoices, isEmpty);
    });

    test('a settings file from before place notifications loads them off', () {
      final s = AppSettings.fromJson({'sounds': false, 'darkMode': true});
      expect(s.placeAlerts, isFalse);
      expect(s.placeAlertChoices, isEmpty);
      expect(s.darkMode, isTrue);
    });

    test('round trip keeps the switch and the choices', () {
      final s = on.withPlaceAlert('Cafe', false).withPlaceAlert('Home', true);
      final back = AppSettings.fromJson(s.toJson());
      expect(back, s);
      expect(back.placeAlertChoices, {'Cafe': false, 'Home': true});
      expect(back.hashCode, s.hashCode);
    });

    test('a bad choices shape loads empty; bad entries are dropped', () {
      expect(
        AppSettings.fromJson({'placeAlertChoices': 'Cafe'}).placeAlertChoices,
        isEmpty,
      );
      final s = AppSettings.fromJson({
        'placeAlerts': 'yes',
        'placeAlertChoices': {' Cafe ': false, 'Park': 'no', '  ': true},
      });
      expect(s.placeAlerts, isFalse);
      expect(s.placeAlertChoices, {'Cafe': false});
    });

    test('home, work and church start quiet, in any case or spacing', () {
      const s = AppSettings();
      expect(s.alertsFor('home'), isFalse);
      expect(s.alertsFor('Home'), isFalse);
      expect(s.alertsFor(' WORK '), isFalse);
      expect(s.alertsFor('Church'), isFalse);
      expect(s.alertsFor('Cafe'), isTrue);
      expect(s.alertsFor('Home office'), isTrue);
    });

    test("Fred's own choice beats the default", () {
      final s = const AppSettings()
          .withPlaceAlert('Home', true)
          .withPlaceAlert('Cafe', false);
      expect(s.alertsFor('Home'), isTrue);
      expect(s.alertsFor(' Home '), isTrue);
      expect(s.alertsFor('Cafe'), isFalse);
      // Keys are exact names, like places themselves.
      expect(s.alertsFor('home'), isFalse);
    });

    test('renaming moves the choice; merging takes the new value', () {
      final s = const AppSettings()
          .withPlaceAlert('Cafe', false)
          .withPlaceAlert('Park', true);
      final renamed = s.renamePlaceAlert('Cafe', 'Coffee', false);
      expect(renamed.placeAlertChoices, {'Park': true, 'Coffee': false});
      final merged = s.renamePlaceAlert('Cafe', 'Park', false);
      expect(merged.placeAlertChoices, {'Park': false});
      expect(s.renamePlaceAlert('Cafe', '  ', true), s);
    });

    test('choices cannot be changed from outside', () {
      final s = const AppSettings().withPlaceAlert('Cafe', true);
      expect(() => s.placeAlertChoices['Park'] = true, throwsUnsupportedError);
    });
  });

  group('planner', () {
    test('no fences while place notifications are off', () {
      final people = [
        person('a', [at('a', 'Cafe', north(0))]),
      ];
      expect(PlaceFencePlanner.plan(people, const AppSettings()), isEmpty);
    });

    test('unnamed places and places without a location are skipped', () {
      final people = [
        person('a', [at('a', '', north(0))]),
        person('b', [at('b', 'Library', null)]),
        person('c', [at('c', 'Cafe', north(5000))]),
      ];
      expect(names(PlaceFencePlanner.plan(people, on)), ['Cafe']);
    });

    test('quiet and silenced places are skipped unless chosen on', () {
      final people = [
        person('a', [at('a', 'Home', north(0))]),
        person('b', [at('b', 'Cafe', north(5000))]),
        person('c', [at('c', 'Church', north(9000))]),
      ];
      final s = on.withPlaceAlert('Cafe', false).withPlaceAlert('Church', true);
      expect(names(PlaceFencePlanner.plan(people, s)), ['Church']);
    });

    test('the centre is the newest located encounter there', () {
      final people = [
        person('a', [at('a', 'Cafe', north(0), day: 1)]),
        person('b', [at('b', 'Cafe', north(100), day: 3)]),
        person('c', [at('c', 'Cafe', null, day: 5)]),
      ];
      final fence = PlaceFencePlanner.plan(people, on).single;
      expect(fence.center, north(100));
    });

    test('the radius follows the setting, but never below 150 m', () {
      final people = [
        person('a', [at('a', 'Cafe', north(0))]),
      ];
      final small = on.copyWith(placeRadiusFeet: 100);
      expect(
        PlaceFencePlanner.plan(people, small).single.radiusMeters,
        PlaceFencePlanner.minRadiusMeters,
      );
      final big = on.copyWith(placeRadiusFeet: 1000);
      expect(
        PlaceFencePlanner.plan(people, big).single.radiusMeters,
        closeTo(304.8, 1e-9),
      );
    });

    test('at most 100 fences, keeping the newest; ties go by name', () {
      final people = [
        for (var i = 0; i < 105; i++)
          person('p$i', [
            at('p$i', 'Place $i', north(i * 1000.0), day: 1 + i ~/ 2),
          ]),
      ];
      final fences = PlaceFencePlanner.plan(people, on);
      expect(fences, hasLength(PlaceFencePlanner.maxFences));
      // Places 104 (day 53) first, then 102 and 103 (day 52) by name.
      expect(names(fences).take(3), ['Place 104', 'Place 102', 'Place 103']);
      expect(names(fences), isNot(contains('Place 0')));
      expect(
        names(PlaceFencePlanner.plan(people.reversed.toList(), on)),
        names(fences),
      );
    });

    test('the fence wire format has the keys the phone reads', () {
      final fence = PlaceFence(
        name: 'Cafe',
        center: const GeoPoint(1.5, -2.5),
        radiusMeters: 150,
      );
      expect(fence.toJson(), {
        'name': 'Cafe',
        'latitude': 1.5,
        'longitude': -2.5,
        'radius': 150.0,
      });
    });
  });
}
