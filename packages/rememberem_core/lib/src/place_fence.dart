import 'geo_point.dart';
import 'place_group.dart';
import 'place_notice.dart';

/// A circle the phone watches for arrival at a named place, by its
/// opaque [id] ([PlaceNotice.fenceId]).
class PlaceFence {
  const PlaceFence({required this.id, required this.at, required this.meters});

  final String id;
  final GeoPoint at;
  final double meters;

  /// Below this, phones' geofencing is unreliable.
  static const leastMeters = 100.0;

  /// The fences to keep: named places with a location ([PlaceGroup.marker],
  /// which follows a moved place), each at its radius from [radiusFor] but
  /// at least [leastMeters], the [most] most recently visited.
  static List<PlaceFence> select(
    List<PlaceGroup> groups,
    double Function(String place) radiusFor, {
    int most = 90,
  }) {
    final named = [
      for (final g in groups)
        if (g.name != null && g.marker != null) g,
    ]..sort((a, b) => b.newest.compareTo(a.newest));
    return [
      for (final g in named.take(most))
        PlaceFence(
          id: PlaceNotice.fenceId(g.name!),
          at: g.marker!,
          meters: radiusFor(g.name!) < leastMeters
              ? leastMeters
              : radiusFor(g.name!),
        ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceFence &&
      other.id == id &&
      other.at == at &&
      other.meters == meters;

  @override
  int get hashCode => Object.hash(id, at, meters);
}
