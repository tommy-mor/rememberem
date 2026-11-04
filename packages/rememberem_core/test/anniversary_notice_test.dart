import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(String id, List<Detail> details) => Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2020),
      fields: {'name': id},
      details: details,
    );

Detail anniversary(String id, DateTime first) => Detail(
      id: id,
      text: '',
      at: DateTime.utc(2020),
      type: DetailKind.anniversary,
      label: 'birthday',
      eventDate: first,
    );

void main() {
  group('AnniversaryFilter', () {
    bool hit(DateTime first, DateTime from, DateTime to) =>
        AnniversaryFilter(from, to)
            .matches(person('a', [anniversary('d', first)]));

    test('matches the month and day in any year from the first date on', () {
      final first = DateTime(1990, 6, 15);
      expect(hit(first, DateTime(2026, 6, 10), DateTime(2026, 6, 17)), isTrue);
      expect(hit(first, DateTime(2026, 6, 15), DateTime(2026, 6, 15)), isTrue);
      expect(hit(first, DateTime(2026, 6, 16), DateTime(2026, 6, 23)), isFalse);
      expect(hit(first, DateTime(2026, 6, 1), DateTime(2026, 6, 14)), isFalse);
    });

    test('a range over the new year', () {
      expect(
        hit(DateTime(2000, 1, 2), DateTime(2026, 12, 28), DateTime(2027, 1, 4)),
        isTrue,
      );
      expect(
        hit(DateTime(2000, 12, 30), DateTime(2026, 12, 28),
            DateTime(2027, 1, 4)),
        isTrue,
      );
    });

    test('not before it first happened; the first day itself counts', () {
      final first = DateTime(2027, 3, 1);
      expect(hit(first, DateTime(2026, 2, 26), DateTime(2026, 3, 5)), isFalse);
      expect(hit(first, DateTime(2027, 2, 26), DateTime(2027, 3, 5)), isTrue);
    });

    test('29 February falls on 28 February in other years', () {
      final first = DateTime(2024, 2, 29);
      expect(hit(first, DateTime(2027, 2, 28), DateTime(2027, 2, 28)), isTrue);
      expect(hit(first, DateTime(2027, 3, 1), DateTime(2027, 3, 1)), isFalse);
      expect(hit(first, DateTime(2028, 2, 29), DateTime(2028, 2, 29)), isTrue);
      expect(hit(first, DateTime(2028, 2, 28), DateTime(2028, 2, 28)), isFalse);
    });

    test('only anniversaries with a date count; blank matches everyone', () {
      final fact =
          Detail(id: 'f', text: 'Born 15 June', at: DateTime.utc(2020));
      final undated = Detail(
        id: 'u',
        text: 'wedding',
        at: DateTime.utc(2026, 6, 15),
        type: DetailKind.anniversary,
      );
      final range =
          AnniversaryFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 30));
      expect(range.matches(person('a', [fact, undated])), isFalse);
      expect(const AnniversaryFilter().isBlank, isTrue);
      expect(AnniversaryFilter(DateTime(2026)).isBlank, isTrue);
      expect(const AnniversaryFilter().matches(person('a', [])), isTrue);
    });
  });

  group('AnniversaryNotice', () {
    test('a notice covers its own day to a week later', () {
      final filter = AnniversaryNotice.filterFor(const LocalDay(2026, 11, 3));
      expect(filter.from, DateTime(2026, 11, 3));
      expect(filter.to, DateTime(2026, 11, 10));
      // Across the end of daylight saving, still whole days.
      final march = AnniversaryNotice.filterFor(const LocalDay(2026, 3, 27));
      expect(march.to, DateTime(2026, 4, 3));
    });

    test('exactly the days whose coming week has an anniversary', () {
      final people = [
        person('a', [anniversary('d', DateTime(1990, 11, 20))]),
      ];
      final days =
          AnniversaryNotice.days(people, const LocalDay(2026, 11, 1), 30);
      expect(days, [
        for (var d = 13; d <= 20; d++) LocalDay(2026, 11, d),
      ]);
    });

    test('no anniversaries, no days', () {
      expect(
        AnniversaryNotice.days(
          [person('a', [])],
          const LocalDay(2026, 11, 1),
          30,
        ),
        isEmpty,
      );
    });

    test('days run across the year end', () {
      final people = [
        person('a', [anniversary('d', DateTime(1990, 1, 2))]),
      ];
      expect(
        AnniversaryNotice.days(people, const LocalDay(2026, 12, 20), 30),
        [
          for (var d = 26; d <= 31; d++) LocalDay(2026, 12, d),
          const LocalDay(2027, 1, 1),
          const LocalDay(2027, 1, 2),
        ],
      );
    });

    test('30 days in a row get 30 different ids', () {
      final ids = {
        for (var i = 0; i < AnniversaryNotice.ahead; i++)
          AnniversaryNotice.idFor(LocalDay.of(DateTime(2026, 12, 20 + i))),
      };
      expect(ids, hasLength(AnniversaryNotice.ahead));
      expect(ids.every((id) => id >= 100 && id < 130), isTrue);
    });

    test(
        'the plan schedules days to come, keeps today once its hour has '
        'passed, and cancels the rest', () {
      const today = LocalDay(2026, 11, 3);
      const tomorrow = LocalDay(2026, 11, 4);
      final after = AnniversaryNotice.plan(
        [today, tomorrow],
        DateTime(2026, 11, 3, 10),
      );
      expect(after.schedule, {AnniversaryNotice.idFor(tomorrow): tomorrow});
      // Today's notice may be showing: its slot is not cancelled.
      expect(after.cancel, isNot(contains(AnniversaryNotice.idFor(today))));
      expect(after.cancel, hasLength(AnniversaryNotice.ahead - 2));

      final before = AnniversaryNotice.plan([today], DateTime(2026, 11, 3, 8));
      expect(before.schedule, {AnniversaryNotice.idFor(today): today});

      final none = AnniversaryNotice.plan([], DateTime(2026, 11, 3));
      expect(none.schedule, isEmpty);
      expect(none.cancel, [for (var id = 100; id < 130; id++) id]);
    });

    test('the payload is a day and nothing else; bad ones are null', () {
      const day = LocalDay(2026, 1, 5);
      expect(AnniversaryNotice.wireId(day), 'anniversaries:2026-01-05');
      expect(
        AnniversaryNotice.dayFromWire(AnniversaryNotice.wireId(day)),
        day,
      );
      for (final bad in [
        null,
        '',
        'faces',
        'anniversaries:2026-02-30',
        'anniversaries:2026-1-5',
        'anniversaries:2026-01-05 ',
        'xanniversaries:2026-01-05',
      ]) {
        expect(AnniversaryNotice.dayFromWire(bad), isNull, reason: '$bad');
      }
    });
  });

  group('ReminderSettings.anniversaries', () {
    test('round-trips, and old files follow the practice switch', () {
      const s = ReminderSettings(
        enabled: true,
        hour: 7,
        minute: 30,
        anniversaries: false,
      );
      expect(ReminderSettings.fromJson(s.toJson()), s);
      expect(
        ReminderSettings.fromJson({'enabled': true, 'hour': 7, 'minute': 0})
            .anniversaries,
        isTrue,
      );
      expect(
        ReminderSettings.fromJson({'enabled': false, 'hour': 7, 'minute': 0})
            .anniversaries,
        isFalse,
      );
    });

    test('a mistyped value is off; defaults are on, off is off', () {
      expect(
        ReminderSettings.fromJson(
          {'enabled': true, 'hour': 7, 'minute': 0, 'anniversaries': 'yes'},
        ),
        const ReminderSettings.off(),
      );
      expect(const ReminderSettings.defaults().anniversaries, isTrue);
      expect(const ReminderSettings.off().anniversaries, isFalse);
    });
  });

  group('what a notice says', () {
    Memory who(String name, List<(String, DateTime)> anniversaries,
            {String id = ''}) =>
        Memory.captured(
          id: id.isEmpty ? name : id,
          photoFileName: 'x.jpg',
          capturedAt: DateTime.utc(2026),
          fields: {'name': name},
          details: [
            for (final (i, (label, on)) in anniversaries.indexed)
              Detail(
                id: '$name$i',
                text: '',
                at: DateTime.utc(2026),
                type: DetailKind.anniversary,
                label: label,
                eventDate: on,
              ),
          ],
        );
    // A Tuesday.
    const day = LocalDay(2026, 11, 3);

    test('names each person, soonest first, the day in words', () {
      final text = AnniversaryNotice.textFor([
        who('Bo', [('wedding', DateTime(2010, 11, 7))]),
        who('Ann Lee', [('birthday', DateTime(1990, 11, 3))]),
        who('Cy', [('first met', DateTime(2020, 11, 4))]),
      ], day);
      expect(
        text,
        "Ann Lee's birthday is today. "
        "Cy's anniversary of when you met is tomorrow. "
        "Bo's wedding anniversary is on Saturday.",
      );
    });

    test('a loss or a custom type gives only the name and the day', () {
      final text = AnniversaryNotice.textFor([
        who('Di', [('lost someone', DateTime(2019, 11, 6))]),
        who('Ed', [('sobriety', DateTime(2021, 11, 10))]),
      ], day);
      expect(
        text,
        'Di has an anniversary on Friday. Ed has an anniversary next Tuesday.',
      );
      expect(text, isNot(contains('lost')));
      expect(text, isNot(contains('sobriety')));
    });

    test('at most three are named; no name is "someone you met"', () {
      final people = [
        for (var i = 0; i < 5; i++)
          who('P$i', [('birthday', DateTime(1990, 11, 4 + i))]),
      ];
      final text = AnniversaryNotice.textFor(people, day);
      expect(text, endsWith('And 2 more.'));
      expect(text, contains('P0'));
      expect(text, isNot(contains('P3')));
      expect(
        AnniversaryNotice.textFor([
          who('', [('birthday', DateTime(1990, 11, 3))], id: 'x'),
        ], day),
        'Someone you met has a birthday today.',
      );
    });

    test('outside the week, or none at all, says so', () {
      expect(
        AnniversaryNotice.textFor([
          who('Bo', [('wedding', DateTime(2010, 11, 20))]),
        ], day),
        'No anniversaries this week.',
      );
    });

    test('a week across the new year finds next January', () {
      final text = AnniversaryNotice.textFor([
        who('Bo', [('birthday', DateTime(1990, 1, 2))]),
      ], const LocalDay(2026, 12, 30));
      expect(text, "Bo's birthday is on Saturday.");
    });
  });
}
