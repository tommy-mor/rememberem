import 'encounter.dart';
import 'geo_point.dart';
import 'memory.dart';

/// Finds the known place nearest to where a photo was taken, from the
/// places already recorded on people's encounters.
class PlaceFinder {
  const PlaceFinder({
    this.radiusMeters = defaultRadiusMeters,
    this.radii = const {},
    this.spots = const {},
  });

  /// 555 feet.
  static const defaultRadiusMeters = 169.164;

  /// How close a known place must be to count (555 feet by default),
  /// unless it has its own radius in [radii].
  final double radiusMeters;

  /// Places' own radii in metres, by trimmed name.
  final Map<String, double> radii;

  /// Where Fred moved places to, by trimmed name. A moved place is
  /// measured from its spot, not from its photos' own locations.
  final Map<String, GeoPoint> spots;

  /// How close a photo must be to [place] to take its name.
  double radiusFor(String place) => radii[place.trim()] ?? radiusMeters;

  /// The encounter with a named place closest to [at] and within that
  /// place's radius ([radiusFor]), or null. Ties go to the newest encounter, so the
  /// order of [people] never matters.
  Encounter? nearest(GeoPoint at, Iterable<Memory> people) {
    Encounter? best;
    var bestDistance = double.infinity;
    for (final memory in people) {
      for (final encounter in memory.encounters) {
        final location = spots[encounter.place.trim()] ?? encounter.location;
        if (location == null || encounter.place.trim().isEmpty) continue;
        final distance = at.distanceTo(location);
        // Written this way round so NaN never passes.
        if (!(distance <= radiusFor(encounter.place))) continue;
        if (distance < bestDistance ||
            (distance == bestDistance &&
                Encounter.newestFirst(encounter, best!) < 0)) {
          best = encounter;
          bestDistance = distance;
        }
      }
    }
    return best;
  }
}
