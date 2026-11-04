import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_files.dart';
import '../reminders/local_notifications_scheduler.dart';
import 'place_arrival.dart';

/// Called by the phone's geofencing, in the background, when Fred has
/// arrived at a watched place (Android: stayed a few minutes; iOS:
/// entered). Shows that place's notice if it is due. Never throws; logs
/// only the kind of error.
@pragma('vm:entry-point')
Future<void> placeArrived(GeofenceCallbackParams params) async {
  // Android sends "dwell" once Fred stays; iOS only "enter".
  final arrived = Platform.isIOS
      ? params.event == GeofenceEvent.enter
      : params.event == GeofenceEvent.dwell;
  if (!arrived) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final files = AppFiles(await getApplicationDocumentsDirectory());
    await PlaceArrival(
      repository: files.repository(),
      reminders: files.reminders(),
      settings: files.settings(),
      log: files.placeNotices(),
      scheduler: LocalNotificationsScheduler(),
    ).handle([for (final g in params.geofences) g.id]);
  } catch (error) {
    debugPrint('Rememberem: place notice failed: ${error.runtimeType}');
  }
}
