import 'local_day.dart';
import 'timeline_group.dart';

/// One date on the timeline and its groups of people.
class TimelineDay {
  const TimelineDay({required this.day, required this.groups});

  final LocalDay day;
  final List<TimelineGroup> groups;
}
