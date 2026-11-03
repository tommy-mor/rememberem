import 'geo_point.dart';

/// A circle around a named place: arriving inside it sends a notice.
class PlaceFence {
  const PlaceFence({
    required this.name,
    required this.center,
    required this.radiusMeters,
  });

  /// The trimmed place name; also what the notice opens the list to.
  final String name;
  final GeoPoint center;
  final double radiusMeters;

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'radius': radiusMeters,
      };

  @override
  bool operator ==(Object other) =>
      other is PlaceFence &&
      other.name == name &&
      other.center == center &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(name, center, radiusMeters);

  @override
  String toString() => 'PlaceFence($name, $center, $radiusMeters)';
}
