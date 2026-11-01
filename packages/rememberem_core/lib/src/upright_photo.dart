import 'dart:typed_data';

/// A JPEG whose pixels are already rotated upright (no EXIF orientation),
/// so face coordinates and crop coordinates agree.
class UprightPhoto {
  const UprightPhoto(this.jpeg, this.width, this.height);

  final Uint8List jpeg;
  final int width;
  final int height;
}
