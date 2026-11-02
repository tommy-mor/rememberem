import 'dart:io';

import 'geo_point.dart';
import 'memory.dart';

/// Private storage for memories and their photos.
abstract interface class MemoryRepository {
  /// Stores [photoJpeg] and creates a memory with empty fields.
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
  });

  /// Saves changes to an existing memory. Throws [StateError] if it has
  /// been purged. Never changes whether it is in the trash.
  Future<void> save(Memory memory);

  /// Active (not trashed) memories, newest first.
  Future<List<Memory>> all();

  /// Trashed memories, most recently trashed first.
  Future<List<Memory>> trashed();

  /// Moves memory [id] to the trash. Deletes nothing.
  Future<void> trash(String id, DateTime at);

  /// Takes memory [id] back out of the trash.
  Future<void> restore(String id);

  /// Deletes trashed memory [id]'s record and photos for good. Safe to
  /// repeat. Throws [StateError] if [id] is not in the trash.
  Future<void> purge(String id);

  File photoFile(Memory memory);
}
