import 'local_day.dart';
import 'meeting_finder.dart';
import 'memory.dart';

/// Which people to show in matching mode. Every set filter must match
/// (AND); a person matches a place, meeting or day if any of their
/// encounters does. Unset or blank filters match everyone.
class MemoryFilter {
  const MemoryFilter({
    this.place,
    this.meeting,
    this.day,
    this.detailsContains = '',
  });

  final String? place;
  final String? meeting;

  /// A calendar day, compared in local time.
  final DateTime? day;

  /// Case-insensitive text to look for in detail texts (not the name).
  final String detailsContains;

  bool get isEmpty =>
      _blank(place) &&
      _blank(meeting) &&
      day == null &&
      detailsContains.trim().isEmpty;

  bool matches(Memory memory) {
    final place = this.place;
    if (!_blank(place) &&
        !memory.encounters
            .any((e) => MeetingFinder.samePlace(e.place, place!))) {
      return false;
    }
    final meeting = this.meeting;
    if (!_blank(meeting) &&
        !memory.encounters.any(
          (e) => MeetingFinder.samePlace(e.meeting, meeting!),
        )) {
      return false;
    }
    final day = this.day;
    if (day != null &&
        !memory.encounters.any((e) => _sameLocalDay(e.capturedAt, day))) {
      return false;
    }
    final needle = detailsContains.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !memory.details.any((d) => d.text.toLowerCase().contains(needle))) {
      return false;
    }
    return true;
  }

  List<Memory> apply(List<Memory> people) => people.where(matches).toList();

  /// The distinct place names among [people]'s encounters, sorted.
  static List<String> places(List<Memory> people) =>
      _distinct([for (final m in people) ...m.encounters.map((e) => e.place)]);

  /// The distinct meeting names among [people]'s encounters, sorted.
  static List<String> meetings(List<Memory> people) => _distinct(
      [for (final m in people) ...m.encounters.map((e) => e.meeting)]);

  static List<String> _distinct(Iterable<String> values) {
    final kept = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (!kept.any((k) => MeetingFinder.samePlace(k, trimmed))) {
        kept.add(trimmed);
      }
    }
    return kept..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  static bool _sameLocalDay(DateTime a, DateTime b) =>
      LocalDay.of(a) == LocalDay.of(b);
}
