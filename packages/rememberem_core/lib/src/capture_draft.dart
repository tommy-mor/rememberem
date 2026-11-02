import 'geo_point.dart';
import 'pixel_rect.dart';
import 'upright_photo.dart';

/// A photo made upright and searched for faces, not yet saved: what Fred
/// chooses faces from. [place] and [meeting] are the suggestions capture
/// would fill in.
class CaptureDraft {
  const CaptureDraft({
    required this.photo,
    required this.faces,
    required this.capturedAt,
    this.location,
    this.place = '',
    this.meeting = '',
  });

  final UprightPhoto photo;

  /// Left to right, then top to bottom.
  final List<PixelRect> faces;
  final DateTime capturedAt;
  final GeoPoint? location;
  final String place;
  final String meeting;

  /// The face a single-person capture keeps, or null for none.
  PixelRect? get largestFace =>
      faces.isEmpty ? null : faces.reduce((a, b) => a.area >= b.area ? a : b);
}
