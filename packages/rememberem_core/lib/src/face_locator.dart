import 'dart:io';

import 'pixel_rect.dart';

/// Finds faces in an upright photo. Implemented per platform by the app.
abstract interface class FaceLocator {
  Future<List<PixelRect>> findFaces(File photo);
}
