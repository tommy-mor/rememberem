import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

/// Keeps memories in a map; records every save.
class FakeMemoryRepository implements MemoryRepository {
  final Map<String, Memory> stored = {};
  final List<Memory> saves = [];

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
    stored[memory.id] = memory;
    saves.add(memory);
  }

  @override
  Future<List<Memory>> all() async => stored.values.toList().reversed.toList();

  @override
  File photoFile(Memory memory) => File('missing/${memory.photoFileName}');
}
