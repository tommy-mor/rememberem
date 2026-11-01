import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'geo_point.dart';
import 'memory.dart';
import 'memory_repository.dart';

/// Stores each memory as `<id>.json` beside its `<id>.jpg` in one folder.
///
/// Pass a folder inside the app's private storage so photos never reach
/// the device gallery.
class JsonFileMemoryRepository implements MemoryRepository {
  JsonFileMemoryRepository(this.folder, {Random? random})
      : _random = random ?? Random();

  final Directory folder;
  final Random _random;

  @override
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
  }) async {
    await folder.create(recursive: true);
    final id = _newId(capturedAt);
    final memory = Memory(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: capturedAt,
      location: location,
    );
    await _writeAtomically(photoFile(memory), photoJpeg);
    await save(memory);
    return memory;
  }

  @override
  Future<void> save(Memory memory) =>
      _writeAtomically(_recordFile(memory.id), utf8.encode(jsonEncode(memory)));

  @override
  Future<List<Memory>> all() async {
    if (!await folder.exists()) return [];
    final memories = <Memory>[];
    await for (final entity in folder.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final json = jsonDecode(await entity.readAsString());
        memories.add(Memory.fromJson(json as Map<String, dynamic>));
      }
    }
    memories.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return memories;
  }

  @override
  File photoFile(Memory memory) =>
      File('${folder.path}${Platform.pathSeparator}${memory.photoFileName}');

  File _recordFile(String id) =>
      File('${folder.path}${Platform.pathSeparator}$id.json');

  String _newId(DateTime capturedAt) =>
      '${capturedAt.microsecondsSinceEpoch.toRadixString(36)}'
      '-${_random.nextInt(1 << 32).toRadixString(36)}';

  /// Writes beside the target then renames, so a crash mid-write never
  /// leaves a half-written record.
  Future<void> _writeAtomically(File target, List<int> bytes) async {
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }
}
