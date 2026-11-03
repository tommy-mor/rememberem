import 'package:rememberem_core/rememberem_core.dart';

import 'place_alert_access.dart';

/// The phone's own watch for Fred arriving at places, as far as place
/// notifications need it. The phone posts the notice itself, even when
/// the app is closed.
abstract interface class PlaceFencer {
  /// What the phone allows now; never asks. Null if it could not tell.
  Future<PlaceAlertAccess?> access();

  /// Asks for whatever is missing, in turn, and says what is still
  /// missing afterwards.
  Future<PlaceAlertAccess> requestAccess();

  /// Watches exactly [fences] from now on (none: stops watching). False
  /// if the phone could not (no location service, location off).
  Future<bool> replace(List<PlaceFence> fences);

  /// The place whose notice launched the app, if one did; given once.
  Future<String?> launchPlace();

  /// Places whose notice was tapped while the app runs.
  Stream<String> get taps;

  /// Rememberem's page in the phone's Settings.
  Future<void> openSettings();
}
