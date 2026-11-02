import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';

/// Keeps memories in a map, with the same trash rules as the real
/// repository; records every save and purge.
class FakeMemoryRepository implements MemoryRepository {
  final Map<String, Memory> stored = {};
  final List<Memory> saves = [];
  final List<String> purges = [];
  final List<(String, String)> merges = [];
  final List<String> deletedPhotos = [];

  /// When true, the next merge throws (and clears this flag).
  bool failNextMerge = false;

  /// When true, the next save throws (and clears this flag).
  bool failNextSave = false;

  @override
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
    String place = '',
    String meeting = '',
  }) async {
    final id = 'm${stored.length}';
    final memory = Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: capturedAt,
      location: location,
      place: place,
      meeting: meeting,
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
    final onDisk = stored[memory.id];
    final saved = memory
        .withTrashedAt(onDisk?.trashedAt)
        .withScore(
          onDisk?.points ?? memory.points,
          onDisk == null ? memory.lastCorrectDate : onDisk.lastCorrectDate,
        )
        .withDetailScores(onDisk?.details ?? const [])
        .withContactKey(onDisk == null ? memory.contactKey : onDisk.contactKey);
    stored[memory.id] = saved;
    saves.add(saved);
  }

  /// Every link set, in order.
  final List<(String, String?)> contactLinks = [];

  @override
  Future<void> setContactKey(String id, String? key) async {
    final onDisk = stored[id];
    if (onDisk == null) throw StateError('Memory $id no longer exists');
    contactLinks.add((id, key));
    stored[id] = onDisk.withContactKey(key);
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

  /// Every recordAnswer call, in order.
  final List<(String, bool)> answers = [];

  @override
  Future<void> recordAnswer(
    String id, {
    required bool correctFirstTry,
    required DateTime at,
  }) async {
    final memory = stored[id];
    if (memory == null || memory.trashedAt != null) {
      throw StateError('Memory $id cannot be scored');
    }
    answers.add((id, correctFirstTry));
    stored[id] = correctFirstTry
        ? memory.withScore(memory.points + 1, at)
        : memory.withScore(0, memory.lastCorrectDate);
  }

  /// Every recordDetailAnswer call, in order.
  final List<(String, String, bool)> detailAnswers = [];

  @override
  Future<void> recordDetailAnswer(
    String memoryId,
    String detailId, {
    required bool correctFirstTry,
    required DateTime at,
  }) async {
    final memory = stored[memoryId];
    if (memory == null ||
        memory.trashedAt != null ||
        !memory.details.any((d) => d.id == detailId)) {
      throw StateError('Detail $detailId cannot be scored');
    }
    detailAnswers.add((memoryId, detailId, correctFirstTry));
    stored[memoryId] = memory.withDetails([
      for (final d in memory.details)
        if (d.id != detailId)
          d
        else if (correctFirstTry)
          d.withScore(d.points + 1, at)
        else
          d.withScore(0, d.lastCorrectDate),
    ]);
  }

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
    _retarget(id, null);
    stored.remove(id);
  }

  /// As the real repository: relationships to [from] now mean [to].
  void _retarget(String from, String? to) {
    for (final id in [...stored.keys]) {
      if (id == from) continue;
      stored[id] = stored[id]!.withRelationshipsRetargeted(from, to);
    }
  }

  @override
  Future<Memory> merge(String survivorId, String discardedId) async {
    if (failNextMerge) {
      failNextMerge = false;
      throw const FileSystemException('disk full');
    }
    final survivor = stored[survivorId];
    final discarded = stored[discardedId];
    if (survivorId == discardedId ||
        survivor == null ||
        discarded == null ||
        survivor.trashedAt != null ||
        discarded.trashedAt != null) {
      throw StateError('Cannot merge $discardedId into $survivorId');
    }
    merges.add((survivorId, discardedId));
    final merged = survivor.merged(
      discarded.withEncounters([
        for (final e in discarded.encounters)
          e.withPhotoFileName('$survivorId.${e.photoFileName}'),
      ]),
    );
    stored[survivorId] = merged;
    _retarget(discardedId, survivorId);
    stored.remove(discardedId);
    purges.add(discardedId);
    return stored[survivorId]!;
  }

  @override
  Future<void> deleteEncounterPhoto(Encounter encounter) async =>
      deletedPhotos.add(encounter.photoFileName);

  @override
  File photoFile(Memory memory) => encounterPhoto(memory.latest);

  @override
  File encounterPhoto(Encounter encounter) =>
      File('missing/${encounter.photoFileName}');
}
