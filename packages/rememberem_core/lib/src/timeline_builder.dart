import 'detail_kind.dart';
import 'encounter.dart';
import 'local_day.dart';
import 'meeting_finder.dart';
import 'memory.dart';
import 'memory_field.dart';
import 'timeline_day.dart';
import 'timeline_group.dart';

/// Lays people out by the days of their happenings, grouped by where and
/// at which meeting. Facts, relationships and anniversaries have no place
/// here. A person with no happenings stands in once, as "recorded" on the
/// day they were first met. Never changes a [Memory].
class TimelineBuilder {
  const TimelineBuilder();

  /// Days newest first; only [only] if given.
  List<TimelineDay> build(List<Memory> active, {LocalDay? only}) {
    final buckets = <_Bucket>[];
    for (final memory in active) {
      final happenings = [
        for (final d in memory.details)
          if (d.kind == DetailKind.happening) d,
      ];
      if (happenings.isEmpty) {
        final first = memory.encounters.last;
        _add(buckets, LocalDay.of(first.capturedAt), first, memory, true);
        continue;
      }
      for (final detail in happenings) {
        final day = LocalDay.of(detail.at);
        _add(
            buckets, day, _encounterFor(memory, day, detail.at), memory, false);
      }
    }
    final byDay = <LocalDay, List<_Bucket>>{};
    for (final bucket in buckets) {
      if (only != null && bucket.day != only) continue;
      byDay.putIfAbsent(bucket.day, () => []).add(bucket);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        TimelineDay(
          day: day,
          groups: (byDay[day]!..sort(_byPlaceThenMeeting))
              .map((b) => b.toGroup())
              .toList(),
        ),
    ];
  }

  /// The encounter that day nearest in time to [at] (ties to the newer),
  /// else the newest encounter.
  Encounter _encounterFor(Memory memory, LocalDay day, DateTime at) {
    Encounter? best;
    Duration? bestGap;
    for (final encounter in memory.encounters) {
      if (LocalDay.of(encounter.capturedAt) != day) continue;
      final gap = at.difference(encounter.capturedAt).abs();
      if (bestGap == null ||
          gap < bestGap ||
          (gap == bestGap && Encounter.newestFirst(encounter, best!) < 0)) {
        best = encounter;
        bestGap = gap;
      }
    }
    return best ?? memory.latest;
  }

  void _add(
    List<_Bucket> buckets,
    LocalDay day,
    Encounter encounter,
    Memory memory,
    bool recorded,
  ) {
    final bucket = buckets.firstWhere(
      (b) =>
          b.day == day &&
          MeetingFinder.samePlace(b.place, encounter.place) &&
          MeetingFinder.samePlace(b.meeting, encounter.meeting),
      orElse: () {
        final created = _Bucket(
          day,
          encounter.place.trim(),
          encounter.meeting.trim(),
        );
        buckets.add(created);
        return created;
      },
    );
    bucket.people.putIfAbsent(memory.id, () => memory);
    if (recorded) bucket.recordedIds.add(memory.id);
  }

  static int _byPlaceThenMeeting(_Bucket a, _Bucket b) {
    final aUnknown = a.place.isEmpty && a.meeting.isEmpty;
    final bUnknown = b.place.isEmpty && b.meeting.isEmpty;
    if (aUnknown != bUnknown) return aUnknown ? 1 : -1;
    for (final (x, y) in [(a.place, b.place), (a.meeting, b.meeting)]) {
      final folded = x.toLowerCase().compareTo(y.toLowerCase());
      if (folded != 0) return folded;
      final exact = x.compareTo(y);
      if (exact != 0) return exact;
    }
    return 0;
  }
}

class _Bucket {
  _Bucket(this.day, this.place, this.meeting);

  final LocalDay day;
  final String place;
  final String meeting;
  final Map<String, Memory> people = {};
  final Set<String> recordedIds = {};

  TimelineGroup toGroup() => TimelineGroup(
        place: place,
        meeting: meeting,
        people: people.values.toList()
          ..sort((a, b) {
            final byName = a
                .field(MemoryField.name)
                .toLowerCase()
                .compareTo(b.field(MemoryField.name).toLowerCase());
            return byName != 0 ? byName : a.id.compareTo(b.id);
          }),
        recordedIds: recordedIds,
      );
}
