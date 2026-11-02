import 'filter_condition.dart';
import 'meeting_finder.dart';
import 'memory.dart';

/// People met at least once at the meeting [name].
class MeetingFilter implements FilterCondition {
  const MeetingFilter([this.name]);

  final String? name;

  @override
  bool get isBlank => (name?.trim() ?? '').isEmpty;

  @override
  bool matches(Memory memory) =>
      isBlank ||
      memory.encounters.any((e) => MeetingFinder.samePlace(e.meeting, name!));
}
