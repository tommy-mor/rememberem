import 'dart:io';

import 'encounter.dart';
import 'geo_point.dart';
import 'memory.dart';

/// Private storage for memories and their photos.
abstract interface class MemoryRepository {
  /// Stores [photoJpeg] and creates a memory met once, at [place] and
  /// [meeting].
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
    String place = '',
    String meeting = '',
  });

  /// Saves changes to an existing memory. Throws [StateError] if it has
  /// been purged. Never changes whether it is in the trash, nor its
  /// practice score (see [recordAnswer]).
  Future<void> save(Memory memory);

  /// Records a face-practice answer for active memory [id]: first try
  /// right adds a point and stamps [at]; otherwise points go to 0. Throws
  /// [StateError] if [id] is trashed or gone.
  Future<void> recordAnswer(
    String id, {
    required bool correctFirstTry,
    required DateTime at,
  });

  /// Records a details-practice answer for detail [detailId] of active
  /// memory [memoryId], as [recordAnswer] does for faces. Throws
  /// [StateError] if the person is trashed or gone, or has no such detail.
  Future<void> recordDetailAnswer(
    String memoryId,
    String detailId, {
    required bool correctFirstTry,
    required DateTime at,
  });

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

  /// Folds [discardedId] into [survivorId]: the survivor gains the other's
  /// photos, encounters, details and (if given) name, then the other is
  /// deleted. Both must be active and different, else [StateError]. If it
  /// fails part-way, running it again finishes the job without duplicates.
  Future<Memory> merge(String survivorId, String discardedId);

  /// The photo that represents [memory]: its newest encounter's.
  File photoFile(Memory memory);

  File encounterPhoto(Encounter encounter);

  /// Deletes just this encounter's photo file (after its encounter has been
  /// removed from the record).
  Future<void> deleteEncounterPhoto(Encounter encounter);
}
