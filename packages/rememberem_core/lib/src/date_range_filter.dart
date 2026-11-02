import 'filter_condition.dart';
import 'local_day.dart';
import 'memory.dart';

/// People met on a local day from [from] to [to], both included. Unset
/// until a range is picked.
class DateRangeFilter implements FilterCondition {
  const DateRangeFilter([this.from, this.to]);

  final DateTime? from;
  final DateTime? to;

  @override
  bool get isBlank => from == null || to == null;

  @override
  bool matches(Memory memory) {
    if (isBlank) return true;
    final first = LocalDay.of(from!);
    final last = LocalDay.of(to!);
    return memory.encounters.any((e) {
      final day = LocalDay.of(e.capturedAt);
      return day.compareTo(first) >= 0 && day.compareTo(last) <= 0;
    });
  }
}
