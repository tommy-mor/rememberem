import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(
  String id, {
  String name = '',
  List<(String place, String meeting, DateTime at)>? met,
  List<String> details = const [],
}) =>
    Memory(
      id: id,
      encounters: [
        for (final (i, (place, meeting, at))
            in (met ?? [('', '', DateTime(2026))]).indexed)
          Encounter(
            photoFileName: '$id-$i.jpg',
            capturedAt: at,
            place: place,
            meeting: meeting,
          ),
      ],
      fields: {'name': name},
      details: [
        for (final (i, text) in details.indexed)
          Detail(id: '$id-d$i', text: text, at: DateTime.utc(2026)),
      ],
    );

MemoryFilter filter(List<FilterCondition> conditions) =>
    MemoryFilter(conditions);

void main() {
  final day = DateTime(2026, 11, 1);

  test('a place matches any encounter, not just the newest', () {
    final alex = person('a', met: [
      ('Cafe', '', DateTime(2026, 1, 1)),
      ('Park', '', DateTime(2026, 6, 1)),
    ]);

    expect(filter([const PlaceFilter('Cafe')]).matches(alex), isTrue);
    expect(filter([const PlaceFilter('Library')]).matches(alex), isFalse);
  });

  test('place names match once trimmed; blank filters match everyone', () {
    final alex = person('a', met: [('Cafe ', '', day)]);

    expect(filter([const PlaceFilter('Cafe')]).matches(alex), isTrue);
    final blank = filter([
      const PlaceFilter(),
      const PlaceFilter('  '),
      const MeetingFilter(),
      const NameFilter(' '),
      const DetailsFilter(),
      DateRangeFilter(day),
    ]);
    expect(blank.isEmpty, isTrue);
    expect(blank.matches(alex), isTrue);
    expect(const MemoryFilter().matches(alex), isTrue);
  });

  test('filters combine with AND; details are searched, the name is not', () {
    final chessAtCafe = person('a',
        name: 'Chess Master',
        met: [('Cafe', '', day)],
        details: ['Loves CHESS']);
    final cafeOnly = person('b', met: [('Cafe', '', day)], details: ['Tall']);
    final chessElsewhere =
        person('c', met: [('Park', '', day)], details: ['chess club']);
    final nameOnly =
        person('d', name: 'Chess', met: [('Cafe', '', day)], details: ['Tall']);

    final matched = filter([
      const PlaceFilter('Cafe'),
      const DetailsFilter('chess'),
    ]).apply([chessAtCafe, cafeOnly, chessElsewhere, nameOnly]);

    expect(matched.map((m) => m.id), ['a']);
  });

  test('two filters of one kind must both match', () {
    final both = person('a', details: ['Tall', 'Plays chess']);
    final one = person('b', details: ['Tall']);

    final matched = filter([
      const DetailsFilter('tall'),
      const DetailsFilter('chess'),
    ]).apply([both, one]);

    expect(matched.map((m) => m.id), ['a']);
  });

  test('a meeting matches any encounter', () {
    final alex = person('a', met: [
      ('Cafe', 'Standup', DateTime(2026, 1, 1)),
      ('Cafe', 'Lunch', DateTime(2026, 2, 1)),
    ]);

    expect(filter([const MeetingFilter('Standup')]).matches(alex), isTrue);
    expect(filter([const MeetingFilter('Choir')]).matches(alex), isFalse);
  });

  test('name contains ignores case; "unknown" finds people with no name', () {
    final named = person('a', name: 'Alex Smith');
    final unnamed = person('b');

    expect(
      filter([const NameFilter('SMITH')]).apply([named, unnamed]).map(
        (m) => m.id,
      ),
      ['a'],
    );
    expect(
      filter([const NameFilter('unknown')]).apply([named, unnamed]).map(
        (m) => m.id,
      ),
      ['b'],
    );
  });

  test('a date range holds local days of any encounter, both ends in', () {
    DateTime on(int d, [int h = 12]) => DateTime(2026, 11, d, h);
    final first = person('a', met: [('Cafe', '', on(1, 0))]);
    final last = person('b', met: [('Cafe', '', on(3, 23))]);
    final before =
        person('c', met: [('Cafe', '', DateTime(2026, 10, 31, 23, 59))]);
    final after = person('d', met: [('Cafe', '', on(4, 0))]);
    final again = person('e', met: [
      ('Cafe', '', DateTime(2025, 1, 1)),
      ('Cafe', '', on(2)),
    ]);

    final matched = filter([DateRangeFilter(on(1), on(3))])
        .apply([first, last, before, after, again]);

    expect(matched.map((m) => m.id), ['a', 'b', 'e']);
  });

  test('places() lists each name once, trimmed, sorted, without blanks', () {
    final people = [
      person('a', met: [('park', '', day), ('Cafe', '', day)]),
      person('b', met: [('Cafe ', '', day), ('  ', '', day)]),
    ];

    expect(MemoryFilter.places(people), ['Cafe', 'park']);
  });
}
