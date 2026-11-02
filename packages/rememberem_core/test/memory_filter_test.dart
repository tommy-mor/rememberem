import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(
  String id, {
  String name = '',
  List<(String place, String meeting, DateTime at)> met = const [],
  List<String> details = const [],
}) =>
    Memory(
      id: id,
      encounters: [
        for (final (i, (place, meeting, at)) in met.indexed)
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

void main() {
  final day = DateTime(2026, 11, 1);

  test('a place matches any encounter, not just the newest', () {
    final alex = person('a', met: [
      ('Cafe', '', DateTime(2026, 1, 1)),
      ('Park', '', DateTime(2026, 6, 1)),
    ]);

    expect(const MemoryFilter(place: 'Cafe').matches(alex), isTrue);
    expect(const MemoryFilter(place: 'Library').matches(alex), isFalse);
  });

  test('place names match once trimmed; blank filters match everyone', () {
    final alex = person('a', met: [('Cafe ', '', day)]);

    expect(const MemoryFilter(place: 'Cafe').matches(alex), isTrue);
    expect(
        const MemoryFilter(place: '  ', detailsContains: ' ').isEmpty, isTrue);
    expect(const MemoryFilter(place: '  ').matches(alex), isTrue);
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

    final matched = const MemoryFilter(place: 'Cafe', detailsContains: 'chess')
        .apply([chessAtCafe, cafeOnly, chessElsewhere, nameOnly]);

    expect(matched.map((m) => m.id), ['a']);
  });

  test('a meeting matches any encounter', () {
    final alex = person('a', met: [
      ('Cafe', 'Standup', DateTime(2026, 1, 1)),
      ('Cafe', 'Lunch', DateTime(2026, 2, 1)),
    ]);

    expect(const MemoryFilter(meeting: 'Standup').matches(alex), isTrue);
  });

  test('day is the local calendar day of any encounter', () {
    final late =
        person('a', met: [('Cafe', '', DateTime(2026, 11, 1, 23, 30))]);

    expect(MemoryFilter(day: DateTime(2026, 11, 1)).matches(late), isTrue);
    expect(MemoryFilter(day: DateTime(2026, 11, 2)).matches(late), isFalse);
  });

  test('places() lists each name once, trimmed, sorted, without blanks', () {
    final people = [
      person('a', met: [('park', '', day), ('Cafe', '', day)]),
      person('b', met: [('Cafe ', '', day), ('  ', '', day)]),
    ];

    expect(MemoryFilter.places(people), ['Cafe', 'park']);
  });
}
