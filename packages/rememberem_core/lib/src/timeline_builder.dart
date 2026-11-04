import 'anniversary_filter.dart';
import 'detail.dart';
import 'detail_kind.dart';
import 'encounter.dart';
import 'local_day.dart';
import 'meeting_finder.dart';
import 'memory.dart';
import 'memory_field.dart';
import 'timeline_day.dart';
import 'timeline_group.dart';

/// Lays people out by the days they were met (each photo), grouped by
/// where and at which meeting. With details, it adds each happening on its
/// day, each dated tag on its date, and each anniversary on its most
/// recent day up to [today], with the details that put a person there.
/// Facts and relationships have no date. Never changes a [Memory].
class TimelineBuilder {
  const TimelineBuilder();

  /// Days newest first; only [only] if given.
  List<TimelineDay> build(
    List<Memory> active, {
    LocalDay? only,
    bool details = false,
    LocalDay? today,
  }) {
    final buckets = <_Bucket>[];
    final now = today ?? LocalDay.of(DateTime.now());
    for (final memory in active) {
      for (final encounter in memory.encounters) {
        _add(
          buckets,
          LocalDay.of(encounter.capturedAt),
          encounter.place,
          encounter.meeting,
          memory,
        );
      }
      if (!details) continue;
      for (final detail in memory.details) {
        final when = _dayOf(detail, now);
        if (when == null) continue;
        final place = detail.place?.trim() ?? '';
        // No place of its own: where they were met that day, if they
        // were (a happening falls back to the newest meeting, as before).
        final met = place.isNotEmpty
            ? null
            : detail.kind == DetailKind.happening
                ? _encounterFor(memory, when, detail.at)
                : _sameDay(memory, when);
        _add(
          buckets,
          when,
          met?.place ?? place,
          met?.meeting ?? '',
          memory,
          detail: detail,
        );
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

  /// The day [detail] goes on, or null if it has none: a happening's day,
  /// a tag's date, an anniversary's most recent day up to [today] (none
  /// if it is still to come for the first time).
  static LocalDay? _dayOf(Detail detail, LocalDay today) {
    final eventDate = detail.eventDate;
    switch (detail.kind) {
      case DetailKind.happening:
        return LocalDay.of(detail.at);
      case DetailKind.tag:
        return eventDate == null ? null : LocalDay.of(eventDate);
      case DetailKind.anniversary:
        if (eventDate == null) return null;
        for (final year in [today.year, today.year - 1]) {
          final yearStart = LocalDay(year, 1, 1);
          final yearEnd = LocalDay(year, 12, 31);
          final last = yearEnd.compareTo(today) > 0 ? today : yearEnd;
          if (AnniversaryFilter.fallsIn(eventDate, yearStart, last)) {
            return AnniversaryFilter.fallsOn(eventDate, year);
          }
        }
        return null;
      case DetailKind.fact || DetailKind.relationship:
        return null;
    }
  }

  /// The newest encounter on [day], or null.
  static Encounter? _sameDay(Memory memory, LocalDay day) => memory.encounters
      .where((e) => LocalDay.of(e.capturedAt) == day)
      .firstOrNull;

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
    String place,
    String meeting,
    Memory memory, {
    Detail? detail,
  }) {
    final bucket = buckets.firstWhere(
      (b) =>
          b.day == day &&
          MeetingFinder.samePlace(b.place, place) &&
          MeetingFinder.samePlace(b.meeting, meeting),
      orElse: () {
        final created = _Bucket(day, place.trim(), meeting.trim());
        buckets.add(created);
        return created;
      },
    );
    bucket.people.putIfAbsent(memory.id, () => memory);
    if (detail != null) {
      bucket.details.putIfAbsent(memory.id, () => []).add(detail);
    }
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
  final Map<String, List<Detail>> details = {};

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
        details: details,
      );
}
