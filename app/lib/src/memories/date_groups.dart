/// One run of items under a heading.
class DateGroup<T> {
  const DateGroup(this.label, this.items);

  final String label;
  final List<T> items;
}

/// Sorts dated items into the headings a list shows: "This week" (Monday
/// 00:00 local until now, and any future date), "Last week" (the seven days
/// before), then months ("October", or "October 2025" for earlier years).
/// A list that shows when things were put in the trash also has "Today"
/// (since local midnight). The clock is given, so a test can move it.
class DateGroups {
  const DateGroups(this.clock, {this.withToday = false});

  final DateTime Function() clock;
  final bool withToday;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// The heading for [when], by the calendar of the clock's own zone.
  String labelFor(DateTime when) {
    final now = clock().toLocal();
    final date = when.toLocal();
    // Built from calendar fields, so a daylight-saving week is still seven
    // days.
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final lastWeekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1) - 7,
    );
    if (withToday && !date.isBefore(today) && date.isBefore(tomorrow)) {
      return 'Today';
    }
    if (!date.isBefore(weekStart)) return 'This week';
    if (!date.isBefore(lastWeekStart)) return 'Last week';
    final month = _months[date.month - 1];
    return date.year == now.year ? month : '$month ${date.year}';
  }

  /// [items], in the order given, in runs that share a heading. An order
  /// that returns to an earlier heading (people with no name come last)
  /// starts a new run, so a heading never covers items it does not match.
  List<DateGroup<T>> group<T>(List<T> items, DateTime Function(T item) dateOf) {
    final groups = <DateGroup<T>>[];
    for (final item in items) {
      final label = labelFor(dateOf(item));
      if (groups.isEmpty || groups.last.label != label) {
        groups.add(DateGroup(label, [item]));
      } else {
        groups.last.items.add(item);
      }
    }
    return groups;
  }
}
