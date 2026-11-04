import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'src/app/app_files.dart';
import 'src/app/app_services.dart';
import 'src/app/meet_shortcut.dart';
import 'src/app/rememberem_app.dart';
import 'src/capture/android_photo_picker.dart';
import 'src/capture/gallery_photo_picker.dart';
import 'src/capture/ml_kit_face_locator.dart';
import 'src/contacts/android_contacts_service.dart';
import 'src/location/device_location.dart';
import 'src/places/device_background_location.dart';
import 'src/places/native_place_fences.dart';
import 'src/places/place_notice_keeper.dart';
import 'src/practice/device_game_feedback.dart';
import 'src/reminders/local_notifications_scheduler.dart';
import 'src/reminders/reminder_coordinator.dart';
import 'src/settings/app_settings_controller.dart';
import 'src/sound/android_haptics.dart';
import 'src/sound/device_sounds.dart';
import 'src/sound/system_haptics.dart';
import 'src/speech/cued_dictation.dart';
import 'src/speech/device_dictation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App-private storage: not visible in the gallery or to other apps.
  final files = AppFiles(await getApplicationDocumentsDirectory());
  final cache = await getTemporaryDirectory();
  final repository = files.repository();
  final reminders = ReminderCoordinator(
    scheduler: LocalNotificationsScheduler(),
    store: files.reminders(),
    repository: repository,
  );
  final settingsStore = files.settings();
  final settings = AppSettingsController(
    await settingsStore.load(),
    settingsStore,
  );
  final placeNotices = PlaceNoticeKeeper(
    fences: NativePlaceFences(),
    location: DeviceBackgroundLocation(),
    reminders: reminders,
    repository: repository,
    settings: settings,
  );
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
    placeNotices: placeNotices,
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
  );
  runApp(RememberemApp(services: services, shortcut: MeetShortcut()));
  // Re-assert the reminder and the watched places on every open (time
  // zone, reboot, new people).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      reminders.sync().catchError(
        (Object e) =>
            debugPrint('Rememberem: reminder sync failed: ${e.runtimeType}'),
      ),
    );
    unawaited(
      placeNotices.sync().catchError(
        (Object e) =>
            debugPrint('Rememberem: place sync failed: ${e.runtimeType}'),
      ),
    );
  });
}
