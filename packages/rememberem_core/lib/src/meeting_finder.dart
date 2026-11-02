import 'encounter.dart';
import 'memory.dart';

/// Suggests the meeting going on at a place. A meeting is a weekly thing,
/// a place plus a day of the week and a time of day: one recorded at the
/// park on a Tuesday at 15:00 matches any Tuesday there around 15:00.
class MeetingFinder {
  const MeetingFinder({this.window = defaultWindow});

  static const defaultWindow = Duration(hours: 2);

  /// How far apart in time of week two encounters may be and still match.
  final Duration window;

  static const _minutesPerWeek = 7 * 24 * 60;

  /// Whether two place (or meeting) names are the same: equal once
  /// trimmed, case-sensitive. Shared so every feature agrees.
  static bool samePlace(String a, String b) => a.trim() == b.trim();

  /// The meeting at [place] closest in time of week to [at] (either side,
  /// within [window] inclusive), or '' if none. Ties go to the newest
  /// encounter.
  String suggest(String place, DateTime at, Iterable<Memory> people) {
    if (place.trim().isEmpty) return '';
    Encounter? best;
    int? bestGap;
    for (final memory in people) {
      for (final encounter in memory.encounters) {
        if (encounter.meeting.trim().isEmpty ||
            !samePlace(encounter.place, place)) {
          continue;
        }
        final gap = weekGap(at, encounter.capturedAt);
        if (gap > window.inMinutes) continue;
        if (bestGap == null ||
            gap < bestGap ||
            (gap == bestGap && Encounter.newestFirst(encounter, best!) < 0)) {
          best = encounter;
          bestGap = gap;
        }
      }
    }
    return best?.meeting.trim() ?? '';
  }

  /// Minutes between [a] and [b] measured around the week in local time,
  /// ignoring which week: Sunday 23:30 is 60 minutes from Monday 00:30.
  static int weekGap(DateTime a, DateTime b) {
    final diff = (_minuteOfWeek(a) - _minuteOfWeek(b)).abs();
    return diff > _minutesPerWeek ~/ 2 ? _minutesPerWeek - diff : diff;
  }

  static int _minuteOfWeek(DateTime at) {
    final local = at.toLocal();
    return (local.weekday - 1) * 24 * 60 + local.hour * 60 + local.minute;
  }
}
