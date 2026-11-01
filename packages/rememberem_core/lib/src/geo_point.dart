/// A latitude/longitude pair in decimal degrees.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );

  final double latitude;
  final double longitude;

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
