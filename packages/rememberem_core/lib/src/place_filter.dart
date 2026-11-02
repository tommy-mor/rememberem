import 'filter_condition.dart';
import 'meeting_finder.dart';
import 'memory.dart';

/// People met at least once at [name].
class PlaceFilter implements FilterCondition {
  const PlaceFilter([this.name]);

  final String? name;

  @override
  bool get isBlank => (name?.trim() ?? '').isEmpty;

  @override
  bool matches(Memory memory) =>
      isBlank ||
      memory.encounters.any((e) => MeetingFinder.samePlace(e.place, name!));
}
