import 'dart:convert';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory metAt(String id, String name, String place,
        {DateTime? at, GeoPoint? location}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: at ?? DateTime.utc(2026),
      fields: {'name': name},
      place: place,
      location: location,
    );

void main() {
  group('fence ids', () {
    test('opaque, stable, and the same for the same place with spaces', () {
      final id = PlaceNotice.fenceId('Cafe');
      expect(id, matches(RegExp(r'^f[0-9a-f]{8}$')));
      expect(id, isNot(contains('Cafe')));
      expect(PlaceNotice.fenceId(' Cafe '), id);
      expect(PlaceNotice.fenceId('cafe'), isNot(id));
      expect(PlaceNotice.fenceId('Park'), isNot(id));
      expect(PlaceNotice.placeFor(id, ['Park', 'Cafe']), 'Cafe');
      expect(PlaceNotice.placeFor(id, ['Park']), isNull);
    });

    test('a tap payload round-trips; anything else is refused', () {
      final id = PlaceNotice.fenceId('Cafe');
      expect(PlaceNotice.fenceFromWire(PlaceNotice.wireId(id)), id);
      for (final junk in [
        null,
        '',
        'arrival:Cafe',
        'arrival:f123',
        'anniversaries:2026-11-03',
        PracticeGame.faces.wireId,
      ]) {
        expect(PlaceNotice.fenceFromWire(junk), isNull, reason: junk);
      }
      expect(AnniversaryNotice.dayFromWire(PlaceNotice.wireId(id)), isNull);
      expect(PracticeGame.fromWireId(PlaceNotice.wireId(id)), isNull);
    });
  });

  group('what it says', () {
    test('names who was met there, at most three', () {
      final people = [
        metAt('a', 'Ann Lee', 'Cafe'),
        metAt('b', 'Bo', 'Cafe '),
        metAt('c', 'Cy', 'Park'),
      ];
      expect(PlaceNotice.textFor(people, 'Cafe'),
          "You've met Ann Lee and Bo here.");
      expect(PlaceNotice.textFor(people, 'Gym'), isNull);
      expect(PlaceNotice.title(' Cafe '), 'At Cafe');

      final many = [
        for (var i = 0; i < 5; i++) metAt('p$i', 'P$i', 'Cafe'),
        metAt('x', '', 'Cafe'),
      ];
      expect(PlaceNotice.textFor(many, 'Cafe'),
          "You've met P0, P1, P2 and 3 more here.");
      expect(PlaceNotice.textFor([metAt('x', '', 'Cafe')], 'Cafe'),
          "You've met someone here.");
    });

    test('once per place in twelve hours', () {
      final at = DateTime.utc(2026, 11, 3, 9);
      expect(PlaceNotice.due(null, at), isTrue);
      expect(PlaceNotice.due(at, at.add(const Duration(hours: 11))), isFalse);
      expect(PlaceNotice.due(at, at.add(const Duration(hours: 12))), isTrue);
    });
  });

  group('which places get a fence', () {
    test(
        'named places with a location, newest first, at least 100 m, '
        'following a moved place', () {
      const here = GeoPoint(47, -122);
      const moved = GeoPoint(47.1, -122);
      final groups = PlaceBook.from([
        metAt('a', 'A', 'Cafe', location: here, at: DateTime.utc(2026, 1)),
        metAt('b', 'B', 'Park', location: here, at: DateTime.utc(2026, 3)),
        metAt('c', 'C', '', location: here),
        metAt('d', 'D', 'Remote'),
      ], spots: {
        'Cafe': moved
      }).groups;
      final fences = PlaceFence.select(
        groups,
        (place) => place == 'Park' ? 50 : 300,
        notifies: (_) => true,
      );
      expect(fences.map((f) => f.id), [
        PlaceNotice.fenceId('Park'),
        PlaceNotice.fenceId('Cafe'),
      ]);
      expect(fences.first.meters, PlaceFence.leastMeters);
      expect(fences.last.at, moved);
      expect(fences.last.meters, 300);
      expect(
        PlaceFence.select(groups, (_) => 200, notifies: (_) => true, most: 1),
        hasLength(1),
      );
    });

    test('places Fred wants no notice for get no fence', () {
      const here = GeoPoint(47, -122);
      final groups = PlaceBook.from([
        metAt('a', 'A', 'Home', location: here),
        metAt('b', 'B', 'Park', location: here),
      ]).groups;
      final settings = const AppSettings();
      final fences = PlaceFence.select(
        groups,
        (_) => 300,
        notifies: settings.notifies,
      );
      expect(fences.map((f) => f.id), [PlaceNotice.fenceId('Park')]);
    });
  });

  group('notify choices', () {
    test(
        'home, work and church are quiet by default, whatever their case; '
        'other places notify', () {
      const s = AppSettings();
      for (final quiet in ['home', 'Work', 'CHURCH', ' Home ']) {
        expect(s.notifies(quiet), isFalse, reason: quiet);
      }
      expect(s.notifies('Cafe'), isTrue);
      expect(s.notifies('Homestead'), isTrue);
    });

    test("Fred's choice wins, survives JSON and follows a rename", () {
      final s = const AppSettings()
          .withPlaceNotify('Home', true)
          .withPlaceNotify(' Cafe ', false);
      expect(s.notifies('Home'), isTrue);
      expect(s.notifies('Cafe'), isFalse);

      final back = AppSettings.fromJson(jsonDecode(jsonEncode(s)));
      expect(back, s);
      expect(back.notifies('Cafe'), isFalse);

      final renamed = back.withPlaceRenamed('Cafe', 'Corner Cafe');
      expect(renamed.notifies('Corner Cafe'), isFalse);
      expect(renamed.placeNotify.containsKey('Cafe'), isFalse);
    });

    test('a missing or damaged map reads as no choices', () {
      expect(AppSettings.fromJson({}).placeNotify, isEmpty);
      expect(
        AppSettings.fromJson({
          'placeNotify': {'Cafe': 'yes', '': true, 'Park': false},
        }).placeNotify,
        {'Park': false},
      );
    });
  });

  test('place notices are off unless turned on, and round-trip', () {
    expect(const ReminderSettings.defaults().places, isFalse);
    expect(
        ReminderSettings.fromJson({
          'enabled': true,
          'hour': 9,
          'minute': 0,
        }).places,
        isFalse);
    final on = const ReminderSettings.defaults().copyWith(places: true);
    expect(ReminderSettings.fromJson(on.toJson()), on);
    expect(on, isNot(const ReminderSettings.defaults()));
  });
}
