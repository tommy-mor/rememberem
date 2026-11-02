import 'memory.dart';

/// The people met at one place and meeting on one day of the timeline.
class TimelineGroup {
  const TimelineGroup({
    required this.place,
    required this.meeting,
    required this.people,
    required this.recordedIds,
  });

  /// Trimmed; either may be empty.
  final String place;
  final String meeting;

  /// Each person once, sorted by name then id.
  final List<Memory> people;

  /// People shown here only because they were recorded that day (they have
  /// no details yet).
  final Set<String> recordedIds;

  bool get isUnknownPlace => place.isEmpty && meeting.isEmpty;
}
