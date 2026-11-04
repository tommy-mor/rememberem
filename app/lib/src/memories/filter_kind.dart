import 'package:rememberem_core/rememberem_core.dart';

/// The kinds of filter the list offers, in menu order.
enum FilterKind {
  place('Place'),
  meeting('Meeting'),
  name('Name contains'),
  details('Details contain'),
  dateRange('Date range'),
  anniversary('Anniversary'),
  tag('Tag');

  const FilterKind(this.label);

  final String label;

  /// A filter of this kind with nothing chosen yet.
  FilterCondition blank() => switch (this) {
    FilterKind.place => const PlaceFilter(),
    FilterKind.meeting => const MeetingFilter(),
    FilterKind.name => const NameFilter(),
    FilterKind.details => const DetailsFilter(),
    FilterKind.dateRange => const DateRangeFilter(),
    FilterKind.anniversary => const AnniversaryFilter(),
    FilterKind.tag => const TagFilter(),
  };

  static FilterKind of(FilterCondition condition) => switch (condition) {
    PlaceFilter() => FilterKind.place,
    MeetingFilter() => FilterKind.meeting,
    NameFilter() => FilterKind.name,
    DetailsFilter() => FilterKind.details,
    DateRangeFilter() => FilterKind.dateRange,
    AnniversaryFilter() => FilterKind.anniversary,
    TagFilter() => FilterKind.tag,
    _ => throw ArgumentError.value(condition, 'condition'),
  };

  /// [condition] in words, for saying how the list is filtered:
  /// "Place: Cafe", "Date range: 1 Nov 2026 – 3 Nov 2026".
  static String describe(FilterCondition condition) {
    String range(DateTime? from, DateTime? to) => from == null || to == null
        ? 'any'
        : '${DetailPrompt.date(from)} – ${DetailPrompt.date(to)}';
    final value = switch (condition) {
      PlaceFilter(:final name) => name ?? 'any',
      MeetingFilter(:final name) => name ?? 'any',
      NameFilter(:final text) => '"${text.trim()}"',
      DetailsFilter(:final text) => '"${text.trim()}"',
      DateRangeFilter(:final from, :final to) => range(from, to),
      AnniversaryFilter(:final from, :final to) => range(from, to),
      TagFilter(:final name) => name ?? 'any',
      _ => '',
    };
    return '${of(condition).label}: $value';
  }
}
