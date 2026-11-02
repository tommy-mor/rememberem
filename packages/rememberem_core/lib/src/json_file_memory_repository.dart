import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'encounter.dart';
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

  /// Every mutation waits for the one before it, so a slow autosave can
  /// never interleave with a trash or purge.
  Future<void> _tail = Future.value();

  @override
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
  }) =>
      _serial(() async {
        await folder.create(recursive: true);
        final id = _newId(capturedAt);
        final memory = Memory.captured(
          id: id,
          photoFileName: '$id.jpg',
          capturedAt: capturedAt,
          location: location,
        );
        await _writeAtomically(photoFile(memory), photoJpeg);
        await _write(memory);
        return memory;
      });

  @override
  Future<void> save(Memory memory) => _serial(
        // The trash state on disk wins, so a stale copy cannot untrash.
        () => _update(
            memory.id, (onDisk) => memory.withTrashedAt(onDisk.trashedAt)),
      );

  @override
  Future<void> trash(String id, DateTime at) =>
      _serial(() => _update(id, (memory) => memory.withTrashedAt(at)));

  @override
  Future<void> restore(String id) =>
      _serial(() => _update(id, (memory) => memory.withTrashedAt(null)));

  @override
  Future<void> purge(String id) => _serial(() async {
        if (!await folder.exists()) return;
        final record = _recordFile(id);
        if (await record.exists() && _isActive(await record.readAsString())) {
          throw StateError('Memory $id is not in the trash');
        }
        await _deleteFiles(id);
      });

  /// Deletes every file of [id]: photos and temp files first, the record
  /// last. Run only inside [_serial].
  Future<void> _deleteFiles(String id) async {
    final record = _recordFile(id);
    // Photos and temp files first, the record last, so a half-finished
    // purge still shows up in the trash and can be repeated. Matching
    // by name (not by parsing the record) means a corrupt record
    // cannot block it.
    final files = await folder.list().toList();
    for (final entity in files) {
      final name = entity.uri.pathSegments.last;
      if (entity is File &&
          name.startsWith('$id.') &&
          entity.path != record.path) {
        await entity.delete();
      }
    }
    if (await record.exists()) await record.delete();
  }

  @override
  Future<Memory> merge(String survivorId, String discardedId) =>
      _serial(() async {
        if (survivorId == discardedId) {
          throw StateError('Cannot merge $survivorId into itself');
        }
        final survivor = await _readActive(survivorId);
        final discarded = await _readActive(discardedId);
        // Copy the other's photos under the survivor's id first, so they
        // survive the purge below and a repeated merge finds them in place.
        final moved = <Encounter>[];
        for (final encounter in discarded.encounters) {
          final base = encounter.photoFileName
              .replaceAll(RegExp(r"\.jpg$"), '')
              .replaceAll('.', '_');
          final renamed = encounter.withPhotoFileName('$survivorId.$base.jpg');
          final source = encounterPhoto(encounter);
          final target = encounterPhoto(renamed);
          if (!await target.exists() && await source.exists()) {
            await _writeAtomically(target, await source.readAsBytes());
          }
          moved.add(renamed);
        }
        final merged = survivor.merged(discarded.withEncounters(moved));
        await _write(merged);
        // Only now is it safe to delete the other person.
        await _deleteFiles(discardedId);
        return merged;
      });

  @override
  Future<void> deleteEncounterPhoto(Encounter encounter) => _serial(() async {
        final photo = encounterPhoto(encounter);
        if (await photo.exists()) await photo.delete();
      });

  Future<Memory> _readActive(String id) async {
    final record = _recordFile(id);
    if (!await record.exists()) {
      throw StateError('Memory $id no longer exists');
    }
    final memory = Memory.fromJson(
        jsonDecode(await record.readAsString()) as Map<String, dynamic>);
    if (memory.trashedAt != null) {
      throw StateError('Memory $id is in the trash');
    }
    return memory;
  }

  /// True if [json] is a readable record that is not in the trash. A
  /// corrupt record counts as not active, so it can still be purged.
  bool _isActive(String json) {
    try {
      final memory = Memory.fromJson(jsonDecode(json) as Map<String, dynamic>);
      return memory.trashedAt == null;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  @override
  Future<List<Memory>> all() async {
    final active = (await _loadAll()).where((m) => m.trashedAt == null).toList()
      ..sort((a, b) => Encounter.newestFirst(a.latest, b.latest));
    return active;
  }

  @override
  Future<List<Memory>> trashed() async {
    final trashed = (await _loadAll())
        .where((m) => m.trashedAt != null)
        .toList()
      ..sort((a, b) => b.trashedAt!.compareTo(a.trashedAt!));
    return trashed;
  }

  @override
  File photoFile(Memory memory) => encounterPhoto(memory.latest);

  @override
  File encounterPhoto(Encounter encounter) =>
      File('${folder.path}${Platform.pathSeparator}${encounter.photoFileName}');

  Future<List<Memory>> _loadAll() async {
    if (!await folder.exists()) return [];
    final memories = <Memory>[];
    await for (final entity in folder.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final json = jsonDecode(await entity.readAsString());
        memories.add(Memory.fromJson(json as Map<String, dynamic>));
      }
    }
    return memories;
  }

  /// Reads memory [id] from disk, applies [change] and writes it back.
  /// Throws [StateError] if the record no longer exists (e.g. purged).
  Future<void> _update(String id, Memory Function(Memory onDisk) change) async {
    final record = _recordFile(id);
    if (!await record.exists()) {
      throw StateError('Memory $id no longer exists');
    }
    final onDisk = Memory.fromJson(
        jsonDecode(await record.readAsString()) as Map<String, dynamic>);
    await _write(change(onDisk));
  }

  Future<void> _write(Memory memory) =>
      _writeAtomically(_recordFile(memory.id), utf8.encode(jsonEncode(memory)));

  /// Runs [operation] after every earlier mutation. The caller sees its own
  /// error; the chain carries on regardless.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

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
