import 'package:flutter/foundation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'settings_store.dart';

/// The current settings, for every screen to read, and the one way to
/// change them. Changes show at once and are saved in the background.
class AppSettingsController extends ValueNotifier<AppSettings> {
  /// [store] null keeps settings in memory only (tests).
  AppSettingsController([super.value = const AppSettings(), this._store]);

  final SettingsStore? _store;

  Future<void> _saving = Future.value();

  /// Applies [settings] now and saves them, one save at a time so the
  /// last change is the one kept. A failed save leaves the change in use
  /// for this session.
  Future<void> update(AppSettings settings) {
    value = settings;
    final store = _store;
    if (store == null) return Future.value();
    return _saving = _saving
        .then((_) => store.save(settings))
        .catchError(
          (Object e) => debugPrint('Rememberem: settings not saved: $e'),
        );
  }
}
