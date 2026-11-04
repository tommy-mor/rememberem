import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

import '../places/place_notice_log.dart';
import '../reminders/file_reminder_settings_store.dart';
import '../settings/file_settings_store.dart';

/// Where the app keeps its files, all in app-private storage: one place
/// for the app and for work done in the background (a place notice), so
/// both read the same people and settings.
class AppFiles {
  const AppFiles(this.documents);

  final Directory documents;

  String _path(String name) =>
      '${documents.path}${Platform.pathSeparator}$name';

  JsonFileMemoryRepository repository() =>
      JsonFileMemoryRepository(Directory(_path('memories')));

  FileReminderSettingsStore reminders() =>
      FileReminderSettingsStore(File(_path('reminders.json')));

  FileSettingsStore settings() =>
      FileSettingsStore(File(_path('settings.json')));

  /// When each place's notice last showed; opaque ids only, and left out
  /// of backup.
  PlaceNoticeLog placeNotices() =>
      PlaceNoticeLog(File(_path('place_notices.json')));
}
