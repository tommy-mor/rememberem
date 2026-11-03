import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Finds where the phone is, or null if it can't (no permission, no fix).
class DeviceLocation {
  static const fixTimeLimit = Duration(seconds: 8);

  Future<GeoPoint?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return _point(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: fixTimeLimit),
        ),
      );
    } on TimeoutException {
      return _point(await Geolocator.getLastKnownPosition());
    } on Exception {
      return null;
    }
  }

  /// Whether Fred has turned location off for Rememberem.
  Future<bool> denied() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever;
    } on Exception {
      return false;
    }
  }

  GeoPoint? _point(Position? position) =>
      position == null ? null : GeoPoint(position.latitude, position.longitude);
}
