import 'dart:io';

import 'package:rememberem/src/about/link_opener.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/capture/photo_picker.dart';
import 'package:rememberem/src/contacts/contacts_service.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/practice/game_feedback.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/speech/dictation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fake_dictation.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

/// A [DeviceLocation] that answers [here] without asking the platform.
class FakeLocation extends DeviceLocation {
  FakeLocation([this.here, this.isDenied = false]);

  GeoPoint? here;
  bool isDenied;

  @override
  Future<GeoPoint?> current() async => here;

  @override
  Future<bool> denied() async => isDenied;
}

/// Services for widget tests. Street maps are off, so nothing touches the
/// network.
AppServices testServices(
  MemoryRepository repository, {
  Dictation? dictation,
  DeviceLocation? location,
  AppSettings settings = const AppSettings(streetMaps: false),
  PhotoPicker? photoPicker,
  GameFeedback? feedback,
  PortraitCapture? capture,
  ContactsService? contacts,
  LinkOpener? links,
}) => AppServices(
  repository: repository,
  capture:
      capture ??
      PortraitCapture(
        repository: repository,
        faceLocator: _NoFaces(),
        workFolder: Directory.systemTemp,
      ),
  dictation: dictation ?? FakeDictation(),
  location: location ?? FakeLocation(),
  settings: AppSettingsController(settings),
  photoPicker: photoPicker,
  feedback: feedback,
  contacts: contacts,
  links: links ?? FakeLinkOpener(),
);

/// Records the links opened; opens nothing.
class FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}
