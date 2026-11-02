import 'filter_condition.dart';
import 'memory.dart';

/// People whose shown name contains [text], ignoring case. The shown name
/// of someone unnamed is [Memory.unknownName], so "unknown" finds them.
class NameFilter implements FilterCondition {
  const NameFilter([this.text = '']);

  final String text;

  @override
  bool get isBlank => text.trim().isEmpty;

  @override
  bool matches(Memory memory) =>
      isBlank ||
      memory.displayName.toLowerCase().contains(text.trim().toLowerCase());
}
