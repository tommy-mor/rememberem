import 'anniversary_filter.dart';
import 'detail_kind.dart';
import 'detail_type_catalog.dart';
import 'local_day.dart';
import 'memory.dart';
import 'memory_field.dart';

/// The daily notice that an anniversary is coming up: which days get one,
/// what it says (who, and when), and what it carries when tapped (only
/// the day).
class AnniversaryNotice {
  const AnniversaryNotice._();

  /// How far ahead a notice looks, after its own day.
  static const week = 7;

  /// How many days of notices are scheduled ahead (within iOS's cap of
  /// 64 pending notifications).
  static const ahead = 30;

  /// The local hour each notice arrives.
  static const hour = 9;

  /// The notice's title: generic, so a glance names no one.
  static const title = 'Anniversaries this week';

  /// The types a notice says aloud, and how. Any other type (a loss, or
  /// one Fred made up) gives only the name and the day: the person's
  /// details are for the app, not a glance over Fred's shoulder.
  static const spokenTypes = {
    'birthday': 'birthday',
    'wedding': 'wedding anniversary',
    'first met': 'anniversary of when you met',
  };

  /// At most this many people are named; the rest are counted.
  static const most = 3;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
    'Friday', 'Saturday', 'Sunday',
  ];

  /// What a notice on [day] says: each of [active] with an anniversary
  /// from [day] to a week later, soonest first. "Ann Lee's birthday is
  /// today. Bo has an anniversary on Saturday."
  static String textFor(List<Memory> active, LocalDay day) {
    final filter = filterFor(day);
    final first = LocalDay.of(filter.from!);
    final last = LocalDay.of(filter.to!);
    final entries = <({LocalDay on, String line})>[];
    for (final person in active) {
      for (final d in person.details) {
        final start = d.eventDate;
        if (d.kind != DetailKind.anniversary || start == null) continue;
        for (final year in {first.year, last.year}) {
          if (!AnniversaryFilter.fallsIn(
              start, LocalDay(year, 1, 1), LocalDay(year, 12, 31))) {
            continue;
          }
          final on = AnniversaryFilter.fallsOn(start, year);
          if (on.compareTo(first) < 0 || on.compareTo(last) > 0) continue;
          entries.add((on: on, line: _line(person, d.label, on, day)));
        }
      }
    }
    if (entries.isEmpty) return 'No anniversaries this week.';
    entries.sort((a, b) {
      final byDay = a.on.compareTo(b.on);
      return byDay != 0 ? byDay : a.line.compareTo(b.line);
    });
    final named = [for (final e in entries.take(most)) e.line].join(' ');
    final rest = entries.length - most;
    return rest > 0 ? '$named And $rest more.' : named;
  }

  static String _line(Memory person, String? label, LocalDay on, LocalDay day) {
    final when = _when(on, day);
    final spoken = spokenTypes[DetailTypeCatalog.normalizeKey(label ?? '')];
    if (person.field(MemoryField.name).trim().isEmpty) {
      return 'Someone you met has ${spoken == null ? 'an anniversary' : 'a $spoken'} $when.';
    }
    final name = person.displayName;
    return spoken == null
        ? '$name has an anniversary $when.'
        : "$name's $spoken is $when.";
  }

  /// "today", "tomorrow", or "on Saturday" (within a week, a weekday
  /// says which).
  static String _when(LocalDay on, LocalDay day) {
    // Calendar days, so a clock change never makes a day short.
    final days = DateTime.utc(on.year, on.month, on.day)
        .difference(DateTime.utc(day.year, day.month, day.day))
        .inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'tomorrow';
    final weekday = _weekdays[on.toDate().weekday - 1];
    return days >= week ? 'next $weekday' : 'on $weekday';
  }

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
