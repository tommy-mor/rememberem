import 'package:rememberem_core/rememberem_core.dart';

import '../about/browser_link_opener.dart';
import '../about/link_opener.dart';
import '../capture/photo_picker.dart';
import '../contacts/contacts_service.dart';
import '../location/device_location.dart';
import '../practice/game_feedback.dart';
import '../reminders/reminder_coordinator.dart';
import '../settings/app_settings_controller.dart';
import '../speech/dictation.dart';

/// The long-lived services the screens share.
class AppServices {
  AppServices({
    required this.repository,
    required this.capture,
    required this.dictation,
    required this.location,
    this.reminders,
    AppSettingsController? settings,
    this.photoPicker,
    this.feedback,
    this.contacts,
    LinkOpener? links,
  }) : settings = settings ?? AppSettingsController(),
       links = links ?? BrowserLinkOpener();

  final MemoryRepository repository;
  final PortraitCapture capture;
  final Dictation dictation;
  final DeviceLocation location;

  /// Daily practice reminders; null where there is no notification system
  /// (tests).
  final ReminderCoordinator? reminders;

  /// Fred's settings; in memory only unless given a store.
  final AppSettingsController settings;

  /// Choosing a photo from the phone; null hides the option (tests).
  final PhotoPicker? photoPicker;

  /// Game sounds and haptics; null is silent (tests).
  final GameFeedback? feedback;

  /// Linking people to phone contacts; null hides it (iOS, tests).
  final ContactsService? contacts;

  /// Opens the About page's links in the browser.
  final LinkOpener links;
}
