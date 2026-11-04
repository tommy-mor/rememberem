import 'filter_condition.dart';
import 'meeting_finder.dart';
import 'memory.dart';

/// Which people the list shows: those matching every condition
/// (AND). Blank conditions match everyone.
class MemoryFilter {
  const MemoryFilter([this.conditions = const []]);

  final List<FilterCondition> conditions;

  bool get isEmpty => conditions.every((c) => c.isBlank);

  bool matches(Memory memory) => conditions.every((c) => c.matches(memory));

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
}
