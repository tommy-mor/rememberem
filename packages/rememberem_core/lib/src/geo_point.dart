import 'dart:math';

/// A latitude/longitude pair in decimal degrees.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );

  final double latitude;
  final double longitude;

  static const _earthRadiusMeters = 6371008.8;

  /// Great-circle (haversine) distance in metres. NaN if either point has
  /// a non-finite coordinate.
  double distanceTo(GeoPoint other) {
    double rad(double degrees) => degrees * pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLon = rad(other.longitude - longitude);
    final a = pow(sin(dLat / 2), 2) +
        cos(rad(latitude)) * cos(rad(other.latitude)) * pow(sin(dLon / 2), 2);
    return 2 * _earthRadiusMeters * asin(sqrt(min(1.0, a)));
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
