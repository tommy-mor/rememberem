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
}) =>
    Memory(
      id: id,
      encounters: encounters,
      fields: {'name': name},
      details: [
        for (final (i, at) in detailTimes.indexed)
          Detail(id: '$id-$i', text: 'detail $i', at: at),
      ],
    );

void main() {
  const builder = TimelineBuilder();
  final d = DateTime(2026, 11, 1);

  List<String> summary(List<TimelineDay> days) => [
        for (final day in days)
          for (final group in day.groups)
            '${day.day.month}/${day.day.day} '
                '${group.isUnknownPlace ? 'Unknown place' : '${group.place}|${group.meeting}'}: '
                '${group.people.map((m) => m.id).join(',')}',
      ];

  test('a detail lands with that day\'s encounter, not the newest', () {
    final alex = person(
      'a',
      [
        met('a1', d.add(const Duration(hours: 10)), place: 'Cafe'),
        met('a2', d.add(const Duration(days: 3)), place: 'Park'),
      ],
      detailTimes: [d.add(const Duration(hours: 11))],
    );

    expect(summary(builder.build([alex])), ['11/1 Cafe|: a']);
  });

  test('the nearest same-day encounter wins; ties go to the newer', () {
    final at = d.add(const Duration(hours: 12));
    Memory alex(List<Encounter> e) => person('a', e, detailTimes: [at]);
    final morning = met('m', d.add(const Duration(hours: 9)), place: 'Morning');
    final noonish = met('n', d.add(const Duration(hours: 13)), place: 'Lunch');
    final early = met('e', d.add(const Duration(hours: 11)), place: 'Early');
    final late = met('l', d.add(const Duration(hours: 13)), place: 'Late');

    expect(
        summary(builder.build([
          alex([morning, noonish])
        ])),
        ['11/1 Lunch|: a']);
    expect(
        summary(builder.build([
          alex([early, late])
        ])),
        ['11/1 Late|: a']);
    expect(
        summary(builder.build([
          alex([late, early])
        ])),
        ['11/1 Late|: a']);
  });

  test('a detail on a day with no encounter uses the newest encounter', () {
    final alex = person(
      'a',
      [met('a1', d, place: 'Cafe', meeting: 'Lunch')],
      // Calendar parts, not d + 120 h: 1 Nov 2026 is a DST change.
      detailTimes: [DateTime(2026, 11, 6)],
    );

    expect(summary(builder.build([alex])), ['11/6 Cafe|Lunch: a']);
  });

  test('blank place and meeting is Unknown place, listed last', () {
    final people = [
      person('a', [met('a1', d)], detailTimes: [d]),
      person('b', [met('b1', d, place: 'Zoo')], detailTimes: [d]),
    ];

    expect(summary(builder.build(people)),
        ['11/1 Zoo|: b', '11/1 Unknown place: a']);
  });

  test('trimmed names merge; different case stays separate', () {
    final people = [
      person('a', [met('a1', d, place: 'Cafe')], detailTimes: [d]),
      person('b', [met('b1', d, place: 'Cafe ')], detailTimes: [d]),
      person('c', [met('c1', d, place: 'cafe')], detailTimes: [d]),
    ];

    expect(
        summary(builder.build(people)), ['11/1 Cafe|: a,b', '11/1 cafe|: c']);
  });

  test('several details that day show the person once, changing nothing', () {
    final alex = person('a', [
      met('a1', d, place: 'Cafe')
    ], detailTimes: [
      d,
      d.add(const Duration(hours: 1)),
      d.add(const Duration(hours: 2))
    ]);

    expect(summary(builder.build([alex])), ['11/1 Cafe|: a']);
    expect(alex.details, hasLength(3));
  });

  test('someone with no details appears once as recorded on their first day',
      () {
    final quiet = person('q', [
      met('q2', d.add(const Duration(days: 9)), place: 'Park'),
      met('q1', d, place: 'Cafe'),
    ]);
    final chatty = person('c', [met('c1', d, place: 'Cafe')], detailTimes: [d]);

    final days = builder.build([quiet, chatty]);

    expect(summary(days), ['11/1 Cafe|: c,q']);
    expect(days.single.groups.single.recordedIds, {'q'});
    expect(quiet.details, isEmpty);
  });

  test('23:30 and 00:30 local fall on different days; newest day first', () {
    final alex = person('a', [
      met('a1', d, place: 'Cafe')
    ], detailTimes: [
      DateTime(2026, 11, 1, 23, 30),
      DateTime(2026, 11, 2, 0, 30),
    ]);

    final days = builder.build([alex]);

    expect(days.map((x) => x.day),
        [const LocalDay(2026, 11, 2), const LocalDay(2026, 11, 1)]);
    expect(
        builder.build([alex], only: const LocalDay(2026, 11, 1)), hasLength(1));
  });

  test('people are sorted by name then id whatever the input order', () {
    final people = [
      person('2', [met('x', d, place: 'Cafe')], name: 'bob', detailTimes: [d]),
      person('1', [met('y', d, place: 'Cafe')], name: 'Bob', detailTimes: [d]),
      person('3', [met('z', d, place: 'Cafe')], name: 'alex', detailTimes: [d]),
    ];

    final ids = summary(builder.build(people));
    final reversed = summary(builder.build(people.reversed.toList()));

    expect(ids, ['11/1 Cafe|: 3,1,2']);
    expect(reversed, ids);
  });

  test('LocalDay gives the same day for a UTC and a local time', () {
    final local = DateTime(2026, 11, 1, 23, 30);

    expect(LocalDay.of(local.toUtc()), LocalDay.of(local));
    expect(LocalDay.of(local), const LocalDay(2026, 11, 1));
  });
}
