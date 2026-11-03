import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'pixel_rect.dart';
import 'upright_photo.dart';

/// JPEG decoding and cropping. Decoding is slow, so the static helpers run
/// the work off the UI isolate. Photos that are kept are shrunk to
/// [longestSide] and saved at [keptQuality], which is plenty for a face on
/// a phone and keeps each photo near 100 KB.
class PortraitCropper {
  const PortraitCropper();

  static const longestSide = 1000;
  static const keptQuality = 75;

  /// The working copy is never kept, only cropped, so it stays sharp.
  static const workingQuality = 95;

  static Future<UprightPhoto> uprightInBackground(List<int> jpeg) =>
      Isolate.run(() => const PortraitCropper().upright(jpeg));

  static Future<Uint8List> cropInBackground(List<int> jpeg, PixelRect rect) =>
      Isolate.run(() => const PortraitCropper().crop(jpeg, rect));

  static Future<Uint8List> shrinkInBackground(List<int> jpeg) =>
      Isolate.run(() => const PortraitCropper().shrink(jpeg));

  /// Applies any EXIF rotation to the pixels themselves.
  UprightPhoto upright(List<int> jpeg) {
    final image = img.bakeOrientation(_decode(jpeg));
    return UprightPhoto(
      img.encodeJpg(image, quality: workingQuality),
      image.width,
      image.height,
    );
  }

  /// The [rect] part of [jpeg], ready to keep.
  Uint8List crop(List<int> jpeg, PixelRect rect) {
    final cropped = img.copyCrop(
      _decode(jpeg),
      x: rect.left,
      y: rect.top,
      width: rect.width,
      height: rect.height,
    );
    return _kept(cropped);
  }

  /// The whole of [jpeg], ready to keep.
  Uint8List shrink(List<int> jpeg) => _kept(_decode(jpeg));

  Uint8List _kept(img.Image image) {
    final longest = image.width > image.height ? image.width : image.height;
    final fitted = longest <= longestSide
        ? image
        : image.width >= image.height
            ? img.copyResize(image, width: longestSide)
            : img.copyResize(image, height: longestSide);
    return img.encodeJpg(fitted, quality: keptQuality);
  }

  img.Image _decode(List<int> jpeg) {
    final image = img.decodeJpg(Uint8List.fromList(jpeg));
    if (image == null) throw const FormatException('Photo is not a JPEG');
    return image;
  }
}
