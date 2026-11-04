import 'detail.dart';
import 'memory.dart';

/// The people met at one place and meeting on one day of the timeline.
class TimelineGroup {
  const TimelineGroup({
    required this.place,
    required this.meeting,
    required this.people,
    this.details = const {},
  });

  /// Trimmed; either may be empty.
  final String place;
  final String meeting;

  /// Each person once, sorted by name then id.
  final List<Memory> people;

  /// By person id, the details that put them here (with "Show details"
  /// on); a person met here has none of their own.
  final Map<String, List<Detail>> details;

  bool get isUnknownPlace => place.isEmpty && meeting.isEmpty;
}
