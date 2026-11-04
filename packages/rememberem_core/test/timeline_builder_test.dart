import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Encounter met(String photo, DateTime at,
        {String place = '', String meeting = ''}) =>
    Encounter(
        photoFileName: photo, capturedAt: at, place: place, meeting: meeting);

Memory person(
  String id,
  List<Encounter> encounters, {
  String name = '',
  List<DateTime> detailTimes = const [],
  List<Detail> more = const [],
}) =>
    Memory(
      id: id,
      encounters: encounters,
      fields: {'name': name},
      details: [
        for (final (i, at) in detailTimes.indexed)
          Detail(
            id: '$id-$i',
            text: 'detail $i',
            at: at,
            type: DetailKind.happening,
          ),
        ...more,
      ],
    );

void main() {
  const builder = TimelineBuilder();
  final d = DateTime(2026, 11, 1);
  const today = LocalDay(2026, 11, 20);

  List<String> summary(List<TimelineDay> days) => [
        for (final day in days)
          for (final group in day.groups)
            '${day.day.month}/${day.day.day} '
                '${group.isUnknownPlace ? 'Unknown place' : '${group.place}|${group.meeting}'}: '
                '${group.people.map((m) => m.id).join(',')}',
      ];

  List<String> withDetails(List<Memory> people) =>
      summary(builder.build(people, details: true, today: today));

  group('without details', () {
    test('everyone sits on each day they were met', () {
      final alex = person('a', [
        met('a2', DateTime(2026, 11, 4, 9), place: 'Park'),
        met('a1', d.add(const Duration(hours: 10)), place: 'Cafe'),
      ], detailTimes: [
        d.add(const Duration(days: 9))
      ]);

      expect(
          summary(builder.build([alex])), ['11/4 Park|: a', '11/1 Cafe|: a']);
      expect(builder.build([alex]).last.groups.single.details, isEmpty);
    });

    test('blank place and meeting is Unknown place, listed last', () {
      final people = [
        person('a', [met('a1', d)]),
        person('b', [met('b1', d, place: 'Zoo')]),
      ];

      expect(summary(builder.build(people)),
          ['11/1 Zoo|: b', '11/1 Unknown place: a']);
    });

    test('trimmed names merge; different case stays separate', () {
      final people = [
        person('a', [met('a1', d, place: 'Cafe')]),
        person('b', [met('b1', d, place: 'Cafe ')]),
        person('c', [met('c1', d, place: 'cafe')]),
      ];

      expect(
          summary(builder.build(people)), ['11/1 Cafe|: a,b', '11/1 cafe|: c']);
    });

    test('23:30 and 00:30 local fall on different days; newest day first', () {
      final alex = person('a', [
        met('a2', DateTime(2026, 11, 2, 0, 30), place: 'Cafe'),
        met('a1', DateTime(2026, 11, 1, 23, 30), place: 'Cafe'),
      ]);

      final days = builder.build([alex]);

      expect(days.map((x) => x.day),
          [const LocalDay(2026, 11, 2), const LocalDay(2026, 11, 1)]);
      expect(builder.build([alex], only: const LocalDay(2026, 11, 1)),
          hasLength(1));
    });

    test('people are sorted by name then id whatever the input order', () {
      final people = [
        person('2', [met('x', d, place: 'Cafe')], name: 'bob'),
        person('1', [met('y', d, place: 'Cafe')], name: 'Bob'),
        person('3', [met('z', d, place: 'Cafe')], name: 'alex'),
      ];

      final ids = summary(builder.build(people));
      expect(ids, ['11/1 Cafe|: 3,1,2']);
      expect(summary(builder.build(people.reversed.toList())), ids);
    });
  });

  group('with details', () {
    test('a happening lands with that day\'s encounter, nearest in time', () {
      final at = d.add(const Duration(hours: 12));
      final alex = person('a', [
        met('n', d.add(const Duration(hours: 13)), place: 'Lunch'),
        met('m', d.add(const Duration(hours: 9)), place: 'Morning'),
      ], detailTimes: [
        at
      ]);

      final days = builder.build([alex], details: true, today: today);
      final lunch = days.single.groups.firstWhere((g) => g.place == 'Lunch');
      expect(lunch.details['a']!.single.id, 'a-0');
      final morning =
          days.single.groups.firstWhere((g) => g.place == 'Morning');
      expect(morning.details, isEmpty);
    });

    test('a happening on a day with no encounter uses the newest encounter',
        () {
      final alex = person(
        'a',
        [met('a1', d, place: 'Cafe', meeting: 'Lunch')],
        // Calendar parts, not d + 120 h: 1 Nov 2026 is a DST change.
        detailTimes: [DateTime(2026, 11, 6)],
      );

      expect(withDetails([alex]), ['11/6 Cafe|Lunch: a', '11/1 Cafe|Lunch: a']);
    });

    test('a happening with its own place goes there', () {
      final alex = person('a', [
        met('a1', d, place: 'Cafe')
      ], more: [
        Detail(
          id: 'h',
          text: 'Picnic',
          at: DateTime(2026, 11, 3, 12),
          type: DetailKind.happening,
          place: 'Park',
        ),
      ]);

      expect(withDetails([alex]), ['11/3 Park|: a', '11/1 Cafe|: a']);
    });

    test('a dated tag goes on its date at its place; an undated one nowhere',
        () {
      final alex = person('a', [
        met('a1', d, place: 'Cafe')
      ], more: [
        Detail(
          id: 't',
          text: '',
          at: d,
          type: DetailKind.tag,
          label: 'book club',
          eventDate: DateTime(2026, 11, 10),
          place: 'Library',
        ),
        Detail(id: 'u', text: '', at: d, type: DetailKind.tag, label: 'choir'),
      ]);

      final days = builder.build([alex], details: true, today: today);
      expect(summary(days), ['11/10 Library|: a', '11/1 Cafe|: a']);
      expect(days.first.groups.single.details['a']!.single.id, 't');
    });

    test('an anniversary goes on its most recent day, never a future one', () {
      Detail anniversary(String id, DateTime first) => Detail(
            id: id,
            text: '',
            at: d,
            type: DetailKind.anniversary,
            label: 'wedding',
            eventDate: first,
          );
      final alex = person('a', [
        met('a1', d, place: 'Cafe')
      ], more: [
        anniversary('past', DateTime(2010, 6, 3)), // this year: 3 Jun 2026
        anniversary('soon', DateTime(2010, 12, 25)), // last year
        anniversary('today', DateTime(2000, 11, 20)), // today counts
        anniversary('future', DateTime(2030, 1, 1)), // not yet: nowhere
      ]);

      final days = builder.build([alex], details: true, today: today);
      final placed = {
        for (final day in days)
          for (final group in day.groups)
            for (final detail in group.details['a'] ?? const <Detail>[])
              detail.id: day.day,
      };
      expect(placed, {
        'past': const LocalDay(2026, 6, 3),
        'soon': const LocalDay(2025, 12, 25),
        'today': const LocalDay(2026, 11, 20),
      });
    });

    test('a dated tag with no place goes where they were met that day', () {
      final alex = person('a', [
        met('a1', DateTime(2026, 11, 10, 9), place: 'Gym'),
        met('a0', d, place: 'Cafe'),
      ], more: [
        Detail(
          id: 't',
          text: '',
          at: d,
          type: DetailKind.tag,
          label: 'club',
          eventDate: DateTime(2026, 11, 10),
        ),
        Detail(
          id: 'w',
          text: '',
          at: d,
          type: DetailKind.anniversary,
          label: 'wedding',
          eventDate: DateTime(2010, 11, 12),
        ),
      ]);

      // The tag's day has a meeting at the gym; the anniversary's has none.
      expect(withDetails([alex]), [
        '11/12 Unknown place: a',
        '11/10 Gym|: a',
        '11/1 Cafe|: a',
      ]);
    });

    test('a leap-day anniversary falls on 28 February in other years', () {
      final alex = person('a', [
        met('a1', d, place: 'Cafe')
      ], more: [
        Detail(
          id: 'leap',
          text: '',
          at: d,
          type: DetailKind.anniversary,
          label: 'birthday',
          eventDate: DateTime(2000, 2, 29),
        ),
      ]);

      final days = builder.build([alex], details: true, today: today);
      expect(days.map((x) => x.day), contains(const LocalDay(2026, 2, 28)));
    });

    test('facts and relationships never reach the timeline', () {
      final alex = person('a', [
        met('a1', d, place: 'Cafe')
      ], more: [
        Detail(id: 'f', text: 'Loves jazz', at: d.add(const Duration(days: 2))),
        Detail(
          id: 'r',
          text: 'Since 2020',
          at: d.add(const Duration(days: 3)),
          type: DetailKind.relationship,
          targetId: 'j',
          label: 'boss',
        ),
      ]);

      expect(withDetails([alex]), ['11/1 Cafe|: a']);
    });

    test('several details that day show the person once, changing nothing', () {
      final alex = person('a', [
        met('a1', d, place: 'Cafe')
      ], detailTimes: [
        d,
        d.add(const Duration(hours: 1)),
        d.add(const Duration(hours: 2)),
      ]);

      final days = builder.build([alex], details: true, today: today);
      expect(summary(days), ['11/1 Cafe|: a']);
      expect(days.single.groups.single.details['a'], hasLength(3));
      expect(alex.details, hasLength(3));
    });
  });

  test('LocalDay gives the same day for a UTC and a local time', () {
    final local = DateTime(2026, 11, 1, 23, 30);

    expect(LocalDay.of(local.toUtc()), LocalDay.of(local));
    expect(LocalDay.of(local), const LocalDay(2026, 11, 1));
  });
}
