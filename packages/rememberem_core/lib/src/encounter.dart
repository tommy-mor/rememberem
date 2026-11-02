import 'geo_point.dart';

/// One time Fred met someone: the photo taken then, and where and when.
/// The photo file name is its identity.
class Encounter {
  Encounter({
    required this.photoFileName,
    required this.capturedAt,
    this.location,
    this.place = '',
    this.meeting = '',
  });

  factory Encounter.fromJson(Map<String, dynamic> json) => Encounter(
        photoFileName: json['photo'] as String,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        location: json['location'] == null
            ? null
            : GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
        place: json['place'] as String? ?? '',
        meeting: json['meeting'] as String? ?? '',
      );

  /// Newest first: latest [capturedAt], ties broken by the greater photo
  /// name, so the order never depends on input order.
  static int newestFirst(Encounter a, Encounter b) {
    final byTime = b.capturedAt.compareTo(a.capturedAt);
    return byTime != 0 ? byTime : b.photoFileName.compareTo(a.photoFileName);
  }

  final String photoFileName;
  final DateTime capturedAt;
  final GeoPoint? location;
  final String place;
  final String meeting;

  Encounter withPlace(String place) => _copy(place: place);
  Encounter withMeeting(String meeting) => _copy(meeting: meeting);
  Encounter withCapturedAt(DateTime at) => _copy(capturedAt: at);
  Encounter withPhotoFileName(String name) => _copy(photoFileName: name);

  Encounter _copy({
    String? photoFileName,
    DateTime? capturedAt,
    String? place,
    String? meeting,
  }) =>
      Encounter(
        photoFileName: photoFileName ?? this.photoFileName,
        capturedAt: capturedAt ?? this.capturedAt,
        location: location,
        place: place ?? this.place,
        meeting: meeting ?? this.meeting,
      );

  Map<String, dynamic> toJson() => {
        'photo': photoFileName,
        'capturedAt': capturedAt.toIso8601String(),
        'location': location?.toJson(),
        'place': place,
        'meeting': meeting,
      };
}
