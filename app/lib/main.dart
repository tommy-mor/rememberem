import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'src/app/app_services.dart';
import 'src/app/meet_shortcut.dart';
import 'src/app/rememberem_app.dart';
import 'src/capture/android_photo_picker.dart';
import 'src/capture/gallery_photo_picker.dart';
import 'src/capture/ml_kit_face_locator.dart';
import 'src/contacts/android_contacts_service.dart';
import 'src/location/device_location.dart';
import 'src/place_alerts/android_place_fencer.dart';
import 'src/place_alerts/place_alert_coordinator.dart';
import 'src/practice/device_game_feedback.dart';
import 'src/reminders/file_reminder_settings_store.dart';
import 'src/reminders/local_notifications_scheduler.dart';
import 'src/reminders/reminder_coordinator.dart';
import 'src/settings/app_settings_controller.dart';
import 'src/settings/file_settings_store.dart';
import 'src/sound/android_haptics.dart';
import 'src/sound/device_sounds.dart';
import 'src/sound/system_haptics.dart';
import 'src/speech/cued_dictation.dart';
import 'src/speech/device_dictation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App-private storage: not visible in the gallery or to other apps.
  final documents = await getApplicationDocumentsDirectory();
  final cache = await getTemporaryDirectory();
  final repository = JsonFileMemoryRepository(
    Directory('${documents.path}${Platform.pathSeparator}memories'),
  );
  final reminders = ReminderCoordinator(
    scheduler: LocalNotificationsScheduler(),
    store: FileReminderSettingsStore(
      File('${documents.path}${Platform.pathSeparator}reminders.json'),
    ),
    repository: repository,
  );
  final settingsStore = FileSettingsStore(
    File('${documents.path}${Platform.pathSeparator}settings.json'),
  );
  final settings = AppSettingsController(
    await settingsStore.load(),
    settingsStore,
  );
  // Android only for now: iOS would need its own region monitoring.
  final placeAlerts = Platform.isAndroid
      ? PlaceAlertCoordinator(
          fencer: AndroidPlaceFencer(),
          settings: settings,
          repository: repository,
        )
      : null;
  final sounds = DeviceSounds(settings);
  final services = AppServices(
    repository: repository,
    capture: PortraitCapture(
      repository: repository,
      faceLocator: MlKitFaceLocator(),
      workFolder: cache,
    ),
    dictation: CuedDictation(DeviceDictation(), sounds),
    location: DeviceLocation(),
    reminders: reminders,
    settings: settings,
    photoPicker: Platform.isAndroid
        ? AndroidPhotoPicker()
        : GalleryPhotoPicker(),
    feedback: DeviceGameFeedback(
      settings,
      sounds,
      Platform.isAndroid ? AndroidHaptics() : SystemHaptics(),
    ),
    // Not built for iOS yet (no contact picker there).
    contacts: Platform.isAndroid ? AndroidContactsService() : null,
    placeAlerts: placeAlerts,
  );
  runApp(RememberemApp(services: services, shortcut: MeetShortcut()));
  // Re-assert the reminder on every open (time zone, reboot, new people).
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(
      reminders.sync().catchError(
        (Object e) => debugPrint('Rememberem: reminder sync failed: $e'),
      ),
    ),
  );
  // And the watched places (reboot, location turned off, new places).
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(
      placeAlerts?.sync().catchError(
        (Object e) => debugPrint('Rememberem: place sync failed: $e'),
      ),
    ),
  );
}
