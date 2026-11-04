import 'package:geolocator/geolocator.dart';

import 'background_location.dart';

/// [BackgroundLocation] through geolocator. "Allow all the time" is never
/// asked for with a second prompt (geolocator 14 crashes on the reply
/// when only the background permission is asked): with location while in
/// use, the app's settings page opens for Fred to choose it there.
class DeviceBackgroundLocation implements BackgroundLocation {
  @override
  Future<bool> granted() async =>
      await Geolocator.checkPermission() == LocationPermission.always;

  @override
  Future<LocationAsk> request() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.always:
          return LocationAsk.granted;
        case LocationPermission.whileInUse:
          return await Geolocator.openAppSettings()
              ? LocationAsk.inSettings
              : LocationAsk.refused;
        case LocationPermission.denied ||
            LocationPermission.deniedForever ||
            LocationPermission.unableToDetermine:
          return LocationAsk.refused;
      }
    } catch (_) {
      return LocationAsk.refused;
    }
  }
}
