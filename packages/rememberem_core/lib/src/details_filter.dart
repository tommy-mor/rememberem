import 'filter_condition.dart';
import 'memory.dart';

/// People with a detail whose description contains [text], ignoring case.
class DetailsFilter implements FilterCondition {
  const DetailsFilter([this.text = '']);

  final String text;

  @override
  bool get isBlank => text.trim().isEmpty;

  @override
  bool matches(Memory memory) {
    if (isBlank) return true;
    final needle = text.trim().toLowerCase();
    return memory.details.any((d) => d.text.toLowerCase().contains(needle));
  }
}
