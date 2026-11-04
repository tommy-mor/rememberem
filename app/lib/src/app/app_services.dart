import 'package:flutter/foundation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/browser_link_opener.dart';
import '../about/link_opener.dart';
import '../capture/photo_picker.dart';
import '../contacts/contacts_service.dart';
import '../location/device_location.dart';
import '../memories/list_filters.dart';
import '../places/place_notice_keeper.dart';
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
    this.placeNotices,
    AppSettingsController? settings,
    this.photoPicker,
    this.feedback,
    this.contacts,
    LinkOpener? links,
    ListFilters? listFilters,
  }) : settings = settings ?? AppSettingsController(),
       links = links ?? BrowserLinkOpener(),
       listFilters = listFilters ?? ListFilters();

  final MemoryRepository repository;
  final PortraitCapture capture;
  final Dictation dictation;
  final DeviceLocation location;

  /// Daily practice reminders; null where there is no notification system
  /// (tests).
  final ReminderCoordinator? reminders;

  /// Notices on arriving at a place; null where there is no geofencing
  /// (tests, unless given).
  final PlaceNoticeKeeper? placeNotices;

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

  /// The main list's filters and order, which notices also set.
  final ListFilters listFilters;

  /// The timeline's "Show details", for this run only.
  final ValueNotifier<bool> timelineDetails = ValueNotifier(false);
}
