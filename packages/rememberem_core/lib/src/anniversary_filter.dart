import 'detail.dart';
import 'detail_kind.dart';
import 'filter_condition.dart';
import 'local_day.dart';
import 'memory.dart';

/// People with an anniversary that falls on a local day from [from] to
/// [to], both included. An anniversary falls on its month and day every
/// year from its first date on; 29 February falls on 28 February in other
/// years. Unset until a range is picked.
class AnniversaryFilter implements FilterCondition {
  const AnniversaryFilter([this.from, this.to]);

  final DateTime? from;
  final DateTime? to;

  @override
  bool get isBlank => from == null || to == null;

  @override
  bool matches(Memory memory) {
    if (isBlank) return true;
    final first = LocalDay.of(from!);
    final last = LocalDay.of(to!);
    return memory.details.any((d) => _matches(d, first, last));
  }

  /// The anniversaries in range.
  List<Detail> detailsIn(Memory memory) {
    if (isBlank) return const [];
    final first = LocalDay.of(from!);
    final last = LocalDay.of(to!);
    return [
      for (final d in memory.details)
        if (_matches(d, first, last)) d,
    ];
  }

  static bool _matches(Detail detail, LocalDay first, LocalDay last) {
    final start = detail.eventDate;
    return detail.kind == DetailKind.anniversary &&
        start != null &&
        fallsIn(start, first, last);
  }

  /// True if a yearly date first on [start] falls on a day from [first] to
  /// [last].
  static bool fallsIn(DateTime start, LocalDay first, LocalDay last) {
    // The range may span a new year, so try each year it touches.
    for (var year = first.year; year <= last.year; year++) {
      if (year < start.year) continue;
      final day = _fallsOn(start, year);
      if (day.compareTo(first) >= 0 && day.compareTo(last) <= 0) return true;
    }
    return false;
  }

  static LocalDay _fallsOn(DateTime start, int year) {
    final leapDay = start.month == 2 && start.day == 29;
    if (leapDay && DateTime(year, 2, 29).month != 2) {
      return LocalDay(year, 2, 28);
    }
    return LocalDay(year, start.month, start.day);
  }
}
