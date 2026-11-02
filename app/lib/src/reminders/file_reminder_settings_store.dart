import 'dart:convert';
import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

import 'reminder_settings_store.dart';

/// Keeps the reminder setting in one small JSON file.
class FileReminderSettingsStore implements ReminderSettingsStore {
  FileReminderSettingsStore(this.file);

  final File file;

  @override
  Future<ReminderSettings> load() async {
    // Missing or unreadable content means off; other I/O errors are not a
    // reason to cancel a working reminder, so they surface instead.
    if (!await file.exists()) return const ReminderSettings.off();
    try {
      return ReminderSettings.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return const ReminderSettings.off();
    }
  }

  @override
  Future<void> save(ReminderSettings settings) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(settings), flush: true);
    await temp.rename(file.path);
  }
}
