import 'dart:math';

import 'pixel_rect.dart';

/// Works out a head-and-shoulders crop around a detected face.
class PortraitFramer {
  const PortraitFramer();

  /// Crop width as a multiple of the face width; wide enough for shoulders.
  static const double widthPerFace = 2.6;

  /// Crop height divided by crop width (a 4:5 portrait).
  static const double aspect = 1.25;

  /// Space above the face, as a fraction of the face height.
  static const double headroom = 0.5;

  /// Returns the crop for [face] within an image of [imageWidth] x
  /// [imageHeight], shrinking it if the face fills most of the photo.
  PixelRect frame(PixelRect face, int imageWidth, int imageHeight) {
    var width = face.width * widthPerFace;
    var height = width * aspect;
    // Where the face centre sits, as a fraction of the crop height.
    final faceCentreRatio = (headroom + 0.5) * face.height / height;

    final scale = [1.0, imageWidth / width, imageHeight / height].reduce(min);
    width *= scale;
    height *= scale;

    final centreX = face.left + face.width / 2;
    final centreY = face.top + face.height / 2;
    final left = (centreX - width / 2).clamp(0.0, imageWidth - width);
    final top =
        (centreY - faceCentreRatio * height).clamp(0.0, imageHeight - height);

    return PixelRect(
      left.round(),
      top.round(),
      min(width.round(), imageWidth - left.round()),
      min(height.round(), imageHeight - top.round()),
    );
  }
}
