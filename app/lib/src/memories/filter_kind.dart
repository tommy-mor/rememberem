import 'package:rememberem_core/rememberem_core.dart';

/// The kinds of filter the Filter List offers, in menu order.
enum FilterKind {
  place('Place'),
  meeting('Meeting'),
  name('Name contains'),
  details('Details contain'),
  dateRange('Date range'),
  anniversary('Anniversary');

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
  };

  static FilterKind of(FilterCondition condition) => switch (condition) {
    PlaceFilter() => FilterKind.place,
    MeetingFilter() => FilterKind.meeting,
    NameFilter() => FilterKind.name,
    DetailsFilter() => FilterKind.details,
    DateRangeFilter() => FilterKind.dateRange,
    AnniversaryFilter() => FilterKind.anniversary,
    _ => throw ArgumentError.value(condition, 'condition'),
  };
}
