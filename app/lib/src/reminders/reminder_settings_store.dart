import 'package:rememberem_core/rememberem_core.dart';

/// Where the reminder setting is kept.
abstract interface class ReminderSettingsStore {
  /// The saved setting, or [ReminderSettings.off] if there is none or it is
  /// garbled. Other read errors are thrown.
  Future<ReminderSettings> load();

  Future<void> save(ReminderSettings settings);
}
