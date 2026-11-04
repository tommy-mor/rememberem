import 'detail.dart';
import 'filter_condition.dart';
import 'memory.dart';

/// People with a detail whose description or type (a relationship's
/// "boss", a tag's "book club") contains [text], ignoring case.
class DetailsFilter implements FilterCondition {
  const DetailsFilter([this.text = '']);

  final String text;

  @override
  bool get isBlank => text.trim().isEmpty;

  String get _needle => text.trim().toLowerCase();

  @override
  bool matches(Memory memory) => isBlank || detailsIn(memory).isNotEmpty;

  /// The details that match, in the person's order.
  List<Detail> detailsIn(Memory memory) {
    if (isBlank) return const [];
    return [
      for (final d in memory.details)
        if (d.text.toLowerCase().contains(_needle) ||
            (d.label ?? '').toLowerCase().contains(_needle))
          d,
    ];
  }

  /// Where the text sits in [s], ignoring case, as (start, end) pairs, for
  /// highlighting.
  List<(int, int)> spans(String s) {
    if (isBlank) return const [];
    final hay = s.toLowerCase();
    final needle = _needle;
    final found = <(int, int)>[];
    var at = hay.indexOf(needle);
    while (at >= 0) {
      found.add((at, at + needle.length));
      at = hay.indexOf(needle, at + needle.length);
    }
    return found;
  }
}
