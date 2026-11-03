import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rememberem/src/capture/ml_kit_face_locator.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Runs the real ML Kit detector on a device, which unit tests can't do.
/// The portrait is 500x625 with the face at roughly (255..355, 95..215).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late List<int> portrait;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('face_test_');
    portrait = (await rootBundle.load('integration_test/assets/portrait.jpg'))
        .buffer
        .asUint8List();
  });

  tearDown(() => temp.delete(recursive: true));

  testWidgets('ML Kit finds the face in a portrait', (tester) async {
    final photo = File('${temp.path}/portrait.jpg');
    await photo.writeAsBytes(portrait);

    final faces = await MlKitFaceLocator().findFaces(photo);

    expect(faces, hasLength(1));
    final face = faces.single;
    expect(face.left + face.width / 2, inInclusiveRange(270, 340));
    expect(face.top + face.height / 2, inInclusiveRange(120, 200));
  });

  testWidgets('a capture is saved cropped to head and shoulders', (
    tester,
  ) async {
    final repository = JsonFileMemoryRepository(Directory('${temp.path}/m'));
    final capture = PortraitCapture(
      repository: repository,
      faceLocator: MlKitFaceLocator(),
      workFolder: Directory('${temp.path}/work'),
    );

    final memory = await capture.capture(
      portrait,
      capturedAt: DateTime.now(),
      location: const GeoPoint(47.61, -122.33),
    );

    final saved = await decodeImageFromList(
      await repository.photoFile(memory).readAsBytes(),
    );
    expect(saved.width, lessThan(500));
    expect(saved.height / saved.width, closeTo(PortraitFramer.aspect, 0.02));
    expect(
      (await repository.all()).single.location,
      const GeoPoint(47.61, -122.33),
    );
  });
}
