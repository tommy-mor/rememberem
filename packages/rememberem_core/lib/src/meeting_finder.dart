import 'encounter.dart';
import 'memory.dart';

/// Suggests the meeting going on at a place: the one recorded there
/// closest in time, if it is within [window] of the new photo.
class MeetingFinder {
  const MeetingFinder();

  static const window = Duration(hours: 2);

  /// Whether two place (or meeting) names are the same: equal once
  /// trimmed, case-sensitive. Shared so every feature agrees.
  static bool samePlace(String a, String b) => a.trim() == b.trim();

  /// The meeting at [place] closest in time to [at] (either side, within
  /// [window] inclusive), or '' if none. Ties go to the newest encounter.
  String suggest(String place, DateTime at, Iterable<Memory> people) {
    if (place.trim().isEmpty) return '';
    Encounter? best;
    Duration? bestGap;
    for (final memory in people) {
      for (final encounter in memory.encounters) {
        if (encounter.meeting.trim().isEmpty ||
            !samePlace(encounter.place, place)) {
          continue;
        }
        final gap = at.difference(encounter.capturedAt).abs();
        if (gap > window) continue;
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
}
