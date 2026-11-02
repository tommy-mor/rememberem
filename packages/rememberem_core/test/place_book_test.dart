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

List<String> labels(PlaceBook book) => [
      for (final g in book.groups)
        '${g.label}:${g.people.map((m) => m.id).join(',')}',
    ];

void main() {
  test('names group once trimmed; different case stays separate', () {
    final people = [
      Memory(id: 'a', encounters: [at('a', ' Cafe', north(0))]),
      Memory(id: 'b', encounters: [at('b', 'Cafe ', north(10))]),
      Memory(id: 'c', encounters: [at('c', 'cafe', north(20))]),
    ];

    expect(labels(PlaceBook.from(people)), ['Cafe:b,a', 'cafe:c']);
  });

  test('the same groups come out whatever the input order', () {
    final people = [
      Memory(id: 'a', encounters: [at('a', '', north(0), day: 1)]),
      Memory(id: 'b', encounters: [at('b', '', north(50), day: 2)]),
      Memory(id: 'c', encounters: [at('c', 'Park', north(5000), day: 3)]),
    ];

    expect(labels(PlaceBook.from(people.reversed.toList())),
        labels(PlaceBook.from(people)));
  });

  test('unnamed spots join the nearby newest spot; a chain does not grow', () {
    // a (newest) at 0 m, b at 150 m, c at 300 m: c is 300 m from a, beyond
    // the 555 ft (169 m) radius, though only 150 m from b.
    final people = [
      Memory(id: 'a', encounters: [at('a', '', north(0), day: 3)]),
      Memory(id: 'b', encounters: [at('b', '', north(150), day: 2)]),
      Memory(id: 'c', encounters: [at('c', '', north(300), day: 1)]),
    ];

    final groups = PlaceBook.from(people).groups;

    expect(groups, hasLength(2));
    expect(groups.map((g) => g.people.map((m) => m.id).join(',')),
        unorderedEquals(['a,b', 'c']));
    expect(groups.every((g) => g.label == 'unknown'), isTrue);
  });

  test('unnamed spots with no location form one unknown group, no marker', () {
    final people = [
      Memory(id: 'a', encounters: [at('a', '', null)]),
      Memory(id: 'b', encounters: [at('b', ' ', null)]),
    ];

    final group = PlaceBook.from(people).groups.single;

    expect(group.label, 'unknown');
    expect(group.marker, isNull);
    expect(group.people.map((m) => m.id),
        ['b', 'a']); // newest first; ties by photo
  });

  test('a person met at one place twice is listed there once', () {
    final alex = Memory(id: 'a', encounters: [
      at('a1', 'Cafe', north(0), day: 1),
      at('a2', 'Cafe', north(5), day: 2),
      at('a3', 'Park', north(5000), day: 3),
    ]);

    expect(labels(PlaceBook.from([alex])), ['Cafe:a', 'Park:a']);
  });
}
