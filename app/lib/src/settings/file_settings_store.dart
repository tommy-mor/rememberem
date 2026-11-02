import 'dart:convert';
import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

import 'settings_store.dart';

/// Keeps the app settings in one small JSON file.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore(this.file);

  final File file;

  @override
  Future<AppSettings> load() async {
    try {
      if (!await file.exists()) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      // Settings are only preferences: damage must never stop the app.
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(settings), flush: true);
    await temp.rename(file.path);
  }
}
