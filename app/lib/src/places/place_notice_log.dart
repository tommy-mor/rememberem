import 'dart:convert';
import 'dart:io';

/// When each place's notice last showed, by the place's opaque fence id
/// (never its name), so a place is noticed at most once in a while.
/// Damage reads as "never".
class PlaceNoticeLog {
  PlaceNoticeLog(this.file);

  final File file;

  Future<Map<String, DateTime>> _read() async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in json.entries)
          if (key is String && value is String) key: ?DateTime.tryParse(value),
      };
    } catch (_) {
      return {};
    }
  }

  Future<DateTime?> lastShown(String fenceId) async => (await _read())[fenceId];

  Future<void> record(String fenceId, DateTime at) async {
    final all = await _read()
      ..[fenceId] = at.toUtc();
    // Arrivals can be handled in two places at once; each its own temp.
    final temp = File(
      '${file.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temp.writeAsString(
      jsonEncode({
        for (final e in all.entries) e.key: e.value.toIso8601String(),
      }),
    );
    await temp.rename(file.path);
  }
}
