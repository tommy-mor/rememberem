import 'anniversary_filter.dart';
import 'local_day.dart';
import 'memory.dart';

/// The daily notice that an anniversary is coming up: which days get one,
/// and what the notification carries (a day, and nothing about anyone).
class AnniversaryNotice {
  const AnniversaryNotice._();

  /// How far ahead a notice looks, after its own day.
  static const week = 7;

  /// How many days of notices are scheduled ahead (within iOS's cap of
  /// 64 pending notifications).
  static const ahead = 30;

  /// The local hour each notice arrives.
  static const hour = 9;

  static const _prefix = 'anniversaries:';
  static final _pattern = RegExp(r'^anniversaries:(\d{4})-(\d{2})-(\d{2})$');

  /// The anniversaries a notice on [day] is about: [day] to a week later.
  static AnniversaryFilter filterFor(LocalDay day) => AnniversaryFilter(
        day.toDate(),
        DateTime(day.year, day.month, day.day + week),
      );

  /// Of the [count] days from [from], those whose coming week has an
  /// anniversary among [active] (which must exclude trashed people).
  static List<LocalDay> days(List<Memory> active, LocalDay from, int count) {
    final days = <LocalDay>[];
    for (var i = 0; i < count; i++) {
      final day = LocalDay.of(DateTime(from.year, from.month, from.day + i));
      final filter = filterFor(day);
      if (active.any(filter.matches)) days.add(day);
    }
    return days;
  }

  /// Notification ids for notices: one slot per day, from here, so a
  /// day's notice replaces itself and the rest can be cancelled by id.
  static const firstId = 100;

  /// A day's slot; days within [ahead] of each other never share one.
  static int idFor(LocalDay day) {
    final epochDay =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    return firstId + epochDay % ahead;
  }

  /// What to do with [days] at [now]: the notices still to come, by id,
  /// and the ids no day uses (to cancel). A day whose [hour] has passed is
  /// not scheduled again, but keeps its slot, so a notice already showing
  /// is never cleared.
  static ({Map<int, LocalDay> schedule, List<int> cancel}) plan(
    List<LocalDay> days,
    DateTime now,
  ) {
    final schedule = <int, LocalDay>{};
    final used = <int>{};
    for (final day in days) {
      final id = idFor(day);
      used.add(id);
      final at = DateTime(day.year, day.month, day.day, hour);
      if (at.isAfter(now)) schedule[id] = day;
    }
    return (
      schedule: schedule,
      cancel: [
        for (var id = firstId; id < firstId + ahead; id++)
          if (!used.contains(id)) id,
      ],
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String wireId(LocalDay day) =>
      '$_prefix${day.year.toString().padLeft(4, '0')}-'
      '${_two(day.month)}-${_two(day.day)}';

  /// The day a notice was for, or null for anything else (payloads come
  /// from outside the app and are untrusted).
  static LocalDay? dayFromWire(String? wireId) {
    final match = _pattern.firstMatch(wireId ?? '');
    if (match == null) return null;
    final [year, month, day] = [
      for (var i = 1; i <= 3; i++) int.parse(match[i]!),
    ];
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) return null;
    return LocalDay(year, month, day);
  }
}
