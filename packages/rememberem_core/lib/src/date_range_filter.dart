import 'anniversary_filter.dart';
import 'detail.dart';
import 'detail_kind.dart';
import 'encounter.dart';
import 'filter_condition.dart';
import 'local_day.dart';
import 'memory.dart';

/// People with a photo taken, or a dated detail, on a local day from
/// [from] to [to], both included: a happening on its day, a tag on its
/// date, an anniversary on its month and day in any year from its first.
/// Facts and relationships have no date of their own. Unset until a range
/// is picked.
class DateRangeFilter implements FilterCondition {
  const DateRangeFilter([this.from, this.to]);

  final DateTime? from;
  final DateTime? to;

  @override
  bool get isBlank => from == null || to == null;

  @override
  bool matches(Memory memory) =>
      isBlank ||
      encountersIn(memory).isNotEmpty ||
      detailsIn(memory).isNotEmpty;

  /// The photos taken in range, newest first.
  List<Encounter> encountersIn(Memory memory) {
    if (isBlank) return const [];
    return [
      for (final e in memory.encounters)
        if (_inRange(LocalDay.of(e.capturedAt))) e,
    ];
  }

  /// The details whose date falls in range, in the person's order.
  List<Detail> detailsIn(Memory memory) {
    if (isBlank) return const [];
    final first = LocalDay.of(from!);
    final last = LocalDay.of(to!);
    return [
      for (final d in memory.details)
        if (switch (d.kind) {
          DetailKind.happening => _inRange(LocalDay.of(d.at)),
          DetailKind.tag =>
            d.eventDate != null && _inRange(LocalDay.of(d.eventDate!)),
          DetailKind.anniversary => d.eventDate != null &&
              AnniversaryFilter.fallsIn(d.eventDate!, first, last),
          DetailKind.fact || DetailKind.relationship => false,
        })
          d,
    ];
  }

  bool _inRange(LocalDay day) =>
      day.compareTo(LocalDay.of(from!)) >= 0 &&
      day.compareTo(LocalDay.of(to!)) <= 0;
}
