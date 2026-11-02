import 'encounter.dart';
import 'geo_point.dart';
import 'memory.dart';

/// Finds the known place nearest to where a photo was taken, from the
/// places already recorded on people's encounters.
class PlaceFinder {
  const PlaceFinder({this.radiusMeters = defaultRadiusMeters});

  /// 555 feet.
  static const defaultRadiusMeters = 169.164;

  /// How close a known place must be to count (555 feet by default).
  final double radiusMeters;

  /// The encounter with a named place closest to [at] and within
  /// [radiusMeters], or null. Ties go to the newest encounter, so the
  /// order of [people] never matters.
  Encounter? nearest(GeoPoint at, Iterable<Memory> people) {
    Encounter? best;
    var bestDistance = double.infinity;
    for (final memory in people) {
      for (final encounter in memory.encounters) {
        final location = encounter.location;
        if (location == null || encounter.place.trim().isEmpty) continue;
        final distance = at.distanceTo(location);
        // Written this way round so NaN never passes.
        if (!(distance <= radiusMeters)) continue;
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
