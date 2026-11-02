import 'package:rememberem_core/rememberem_core.dart';

/// Where Fred's app settings are kept.
abstract interface class SettingsStore {
  /// The saved settings, or the defaults if there are none or they cannot
  /// be read. Never throws: it runs before the app starts.
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
