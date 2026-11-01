import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'pixel_rect.dart';
import 'upright_photo.dart';

/// JPEG decoding and cropping. Decoding is slow, so the static helpers run
/// the work off the UI isolate.
class PortraitCropper {
  const PortraitCropper();

  static Future<UprightPhoto> uprightInBackground(List<int> jpeg) =>
      Isolate.run(() => const PortraitCropper().upright(jpeg));

  static Future<Uint8List> cropInBackground(List<int> jpeg, PixelRect rect) =>
      Isolate.run(() => const PortraitCropper().crop(jpeg, rect));

  /// Applies any EXIF rotation to the pixels themselves.
  UprightPhoto upright(List<int> jpeg) {
    final image = img.bakeOrientation(_decode(jpeg));
    return UprightPhoto(img.encodeJpg(image), image.width, image.height);
  }

  Uint8List crop(List<int> jpeg, PixelRect rect) {
    final cropped = img.copyCrop(
      _decode(jpeg),
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
    return img.encodeJpg(cropped);
  }

  img.Image _decode(List<int> jpeg) {
    final image = img.decodeJpg(Uint8List.fromList(jpeg));
    if (image == null) throw const FormatException('Photo is not a JPEG');
    return image;
  }
}
