import 'package:geolocator/geolocator.dart';

/// Rememberem's own page in the phone's Settings, where Fred can allow the
/// camera, the microphone, location or photos.
class SystemSettings {
  const SystemSettings();

  Future<void> open() async {
    await Geolocator.openAppSettings();
  }
}
