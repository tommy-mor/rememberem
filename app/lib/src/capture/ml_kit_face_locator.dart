import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// On-device face detection with Google ML Kit (Android and iOS).
class MlKitFaceLocator implements FaceLocator {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  @override
  Future<List<PixelRect>> findFaces(File photo) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(photo.path),
    );
    return [
      for (final face in faces)
        PixelRect(
          face.boundingBox.left.round(),
          face.boundingBox.top.round(),
          face.boundingBox.width.round(),
          face.boundingBox.height.round(),
        ),
    ];
  }
}
