import 'package:rememberem_core/rememberem_core.dart';

/// Where the reminder setting is kept.
abstract interface class ReminderSettingsStore {
  /// The saved setting, [ReminderSettings.defaults] if nothing has been
  /// saved yet, or [ReminderSettings.off] if it is garbled. Other read
  /// errors are thrown.
  Future<ReminderSettings> load();

  /// Whether anything has ever been saved (even something now garbled).
  Future<bool> hasSaved();

  Future<void> save(ReminderSettings settings);
}
