import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'src/app/app_services.dart';
import 'src/app/meet_shortcut.dart';
import 'src/app/rememberem_app.dart';
import 'src/capture/ml_kit_face_locator.dart';
import 'src/location/device_location.dart';
import 'src/speech/device_dictation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App-private storage: not visible in the gallery or to other apps.
  final documents = await getApplicationDocumentsDirectory();
  final cache = await getTemporaryDirectory();
  final repository = JsonFileMemoryRepository(
    Directory('${documents.path}${Platform.pathSeparator}memories'),
  );
  final services = AppServices(
    repository: repository,
    capture: PortraitCapture(
      repository: repository,
      faceLocator: MlKitFaceLocator(),
      workFolder: cache,
    ),
    dictation: DeviceDictation(),
    location: DeviceLocation(),
  );
  runApp(RememberemApp(services: services, shortcut: MeetShortcut()));
}
