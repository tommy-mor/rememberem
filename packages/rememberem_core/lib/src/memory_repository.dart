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

  /// Saves changes to an existing memory.
  Future<void> save(Memory memory);

  /// All memories, newest first.
  Future<List<Memory>> all();

  File photoFile(Memory memory);
}
