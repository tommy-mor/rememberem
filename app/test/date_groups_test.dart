import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/date_groups.dart';

/// All dates are built from local calendar fields, so these hold in any
/// time zone the tests run in. 5 Nov 2026 is a Thursday: this week began
/// Monday 2 Nov and last week on Monday 26 Oct.
void main() {
  DateGroups at(DateTime now, {bool withToday = false}) =>
      DateGroups(() => now, withToday: withToday);

  final thursday = DateTime(2026, 11, 5, 12);

  group('labelFor', () {
    test('Monday 00:00 starts this week; a minute before is last week', () {
      final groups = at(thursday);
      expect(groups.labelFor(DateTime(2026, 11, 2)), 'This week');
      expect(groups.labelFor(DateTime(2026, 11, 1, 23, 59)), 'Last week');
    });

    test('last week runs back seven days, then months', () {
      final groups = at(thursday);
      expect(groups.labelFor(DateTime(2026, 10, 26)), 'Last week');
      expect(groups.labelFor(DateTime(2026, 10, 25, 23, 59)), 'October');
      expect(groups.labelFor(DateTime(2026, 3, 1)), 'March');
    });

    test('earlier years carry the year', () {
      final groups = at(thursday);
      expect(groups.labelFor(DateTime(2025, 10, 3)), 'October 2025');
    });

    test('across New Year: a December date is December of last year', () {
      // Wednesday 6 Jan 2027: this week began Monday 4 Jan.
      final groups = at(DateTime(2027, 1, 6, 9));
      expect(groups.labelFor(DateTime(2027, 1, 4)), 'This week');
      expect(groups.labelFor(DateTime(2027, 1, 2)), 'Last week');
      expect(groups.labelFor(DateTime(2026, 12, 28)), 'Last week');
      expect(groups.labelFor(DateTime(2026, 12, 27)), 'December 2026');
    });

    test('a UTC time is read in local time, Sunday night included', () {
      final groups = at(thursday);
      // Sunday 1 Nov, 8 pm here, whatever the offset: last week.
      expect(groups.labelFor(DateTime(2026, 11, 1, 20).toUtc()), 'Last week');
      // Monday 2 Nov, 1 am here: this week.
      expect(groups.labelFor(DateTime(2026, 11, 2, 1).toUtc()), 'This week');
    });

    test('a UTC time near a month end is read in the local month', () {
      // A UTC time's own month differs from the local one near midnight,
      // ahead of UTC for the first and behind it for the second. In a
      // runner set to UTC the two cannot differ, so this only bites in
      // another zone; one of them bites in any zone but UTC.
      final groups = at(thursday);
      expect(groups.labelFor(DateTime(2026, 10, 1, 0, 30).toUtc()), 'October');
      expect(
        groups.labelFor(DateTime(2026, 9, 30, 23, 30).toUtc()),
        'September',
      );
    });

    test('a week with a daylight-saving change is still Monday to Monday', () {
      // US clocks went forward on Sunday 8 Mar 2026; Thursday 12 Mar.
      final groups = at(DateTime(2026, 3, 12, 12));
      expect(groups.labelFor(DateTime(2026, 3, 9)), 'This week');
      expect(groups.labelFor(DateTime(2026, 3, 8, 23, 59)), 'Last week');
      expect(groups.labelFor(DateTime(2026, 3, 2)), 'Last week');
      expect(groups.labelFor(DateTime(2026, 3, 1, 23, 59)), 'March');
    });

    test('a future date lands in This week', () {
      final groups = at(thursday);
      expect(groups.labelFor(DateTime(2026, 11, 20)), 'This week');
      expect(groups.labelFor(DateTime(2027, 6, 1)), 'This week');
    });

    test('there is no Today unless asked for', () {
      expect(at(thursday).labelFor(DateTime(2026, 11, 5, 8)), 'This week');
    });

    test('Trash: Today is since local midnight', () {
      final groups = at(thursday, withToday: true);
      expect(groups.labelFor(DateTime(2026, 11, 5)), 'Today');
      expect(groups.labelFor(DateTime(2026, 11, 4, 23, 59)), 'This week');
      expect(groups.labelFor(DateTime(2026, 11, 2)), 'This week');
      expect(groups.labelFor(DateTime(2026, 10, 30)), 'Last week');
    });
  });

  group('group', () {
    String dateLabel(DateGroup<DateTime> g) => g.label;

    test('keeps the order given and groups each run', () {
      final items = [
        DateTime(2026, 11, 4),
        DateTime(2026, 11, 3),
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 1),
      ];
      final groups = at(thursday).group(items, (d) => d);
      expect(groups.map(dateLabel), ['This week', 'Last week', 'October']);
      expect(groups.map((g) => g.items.length), [2, 1, 2]);
    });

    test('ascending order puts the oldest group first', () {
      final items = [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 30),
        DateTime(2026, 11, 4),
      ];
      final groups = at(thursday).group(items, (d) => d);
      expect(groups.map(dateLabel), ['October', 'Last week', 'This week']);
    });

    test('a heading is never put over items it does not match', () {
      // People with no name come last, so dates can return.
      final items = [
        DateTime(2026, 11, 4),
        DateTime(2026, 10, 2),
        DateTime(2026, 11, 3),
      ];
      final groups = at(thursday).group(items, (d) => d);
      expect(groups.map(dateLabel), ['This week', 'October', 'This week']);
    });

    test('nothing gives no groups, so no heading shows', () {
      expect(at(thursday).group(<DateTime>[], (d) => d), isEmpty);
    });
  });
}
