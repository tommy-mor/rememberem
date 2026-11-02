import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

/// Keeps memories in a map, with the same trash rules as the real
/// repository; records every save and purge.
class FakeMemoryRepository implements MemoryRepository {
  final Map<String, Memory> stored = {};
  final List<Memory> saves = [];
  final List<String> purges = [];

  /// When true, the next save throws (and clears this flag).
  bool failNextSave = false;

  @override
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
  }) async {
    final id = 'm${stored.length}';
    final memory = Memory(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: capturedAt,
      location: location,
    );
    stored[id] = memory;
    return memory;
  }

  @override
  Future<void> save(Memory memory) async {
    if (failNextSave) {
      failNextSave = false;
      throw const FileSystemException('disk full');
    }
    if (purges.contains(memory.id)) {
      throw StateError('Memory ${memory.id} was purged');
    }
    // Tests may build a memory without add(); treat it as on disk.
    final saved = memory.withTrashedAt(stored[memory.id]?.trashedAt);
    stored[memory.id] = saved;
    saves.add(saved);
  }

  @override
  Future<List<Memory>> all() async => [
    for (final m in stored.values.toList().reversed)
      if (m.trashedAt == null) m,
  ];

  @override
  Future<List<Memory>> trashed() async =>
      stored.values.where((m) => m.trashedAt != null).toList()
        ..sort((a, b) => b.trashedAt!.compareTo(a.trashedAt!));

  @override
  Future<void> trash(String id, DateTime at) async =>
      stored[id] = stored[id]!.withTrashedAt(at);

  @override
  Future<void> restore(String id) async =>
      stored[id] = stored[id]!.withTrashedAt(null);

  @override
  Future<void> purge(String id) async {
    if (stored[id] != null && stored[id]!.trashedAt == null) {
      throw StateError('Memory $id is not in the trash');
    }
    purges.add(id);
    stored.remove(id);
  }

  @override
  File photoFile(Memory memory) => File('missing/${memory.photoFileName}');
}
