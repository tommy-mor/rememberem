import 'dart:io';

import 'face_locator.dart';
import 'geo_point.dart';
import 'memory.dart';
import 'memory_repository.dart';
import 'portrait_cropper.dart';
import 'portrait_framer.dart';

/// Turns a freshly taken photo into a saved, head-and-shoulders [Memory].
class PortraitCapture {
  PortraitCapture({
    required this.repository,
    required this.faceLocator,
    required this.workFolder,
    this.framer = const PortraitFramer(),
  });

  final MemoryRepository repository;
  final FaceLocator faceLocator;

  /// Scratch space for the upright copy handed to [faceLocator].
  final Directory workFolder;
  final PortraitFramer framer;

  /// Crops [rawJpeg] to the largest face found. If there is no face the
  /// whole photo is kept, so the moment is never lost.
  Future<Memory> capture(
    List<int> rawJpeg, {
    required DateTime capturedAt,
    GeoPoint? location,
  }) async {
    final photo = await PortraitCropper.uprightInBackground(rawJpeg);
    await workFolder.create(recursive: true);
    final uprightFile = File(
      '${workFolder.path}${Platform.pathSeparator}'
      'upright-${capturedAt.microsecondsSinceEpoch}.jpg',
    );
    await uprightFile.writeAsBytes(photo.jpeg, flush: true);
    try {
      final faces = await faceLocator.findFaces(uprightFile);
      final List<int> portrait;
      if (faces.isEmpty) {
        portrait = photo.jpeg;
      } else {
        final largest = faces.reduce((a, b) => a.area >= b.area ? a : b);
        final rect = framer.frame(largest, photo.width, photo.height);
        portrait = await PortraitCropper.cropInBackground(photo.jpeg, rect);
      }
      return await repository.add(
        photoJpeg: portrait,
        capturedAt: capturedAt,
        location: location,
      );
    } finally {
      await uprightFile.delete();
    }
  }
}
