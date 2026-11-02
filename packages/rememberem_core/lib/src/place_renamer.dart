import 'meeting_finder.dart';
import 'memory.dart';
import 'memory_repository.dart';
import 'place_group.dart';

/// Renames a place on every encounter that belongs to it.
class PlaceRenamer {
  const PlaceRenamer(this.repository);

  final MemoryRepository repository;

  /// Gives [group] the name [newName]. A named place is renamed on every
  /// encounter with that name, including trashed people (so a restore
  /// does not bring the old name back); an unknown place on exactly its
  /// own encounters. Works on freshly read records so no other edit is
  /// lost, saves each person once, and can be repeated after a failure.
  Future<void> rename(PlaceGroup group, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) throw ArgumentError.value(newName, 'newName', 'blank');
    final targets = {
      for (final (memory, encounter) in group.members)
        '${memory.id}/${encounter.photoFileName}',
    };
    final fresh = [...await repository.all(), ...await repository.trashed()];
    for (final memory in fresh) {
      var changed = false;
      final encounters = [...memory.encounters];
      for (final (i, encounter) in memory.encounters.indexed) {
        if (_belongs(
            group, targets, memory, encounter.place, encounter.photoFileName)) {
          encounters[i] = encounter.withPlace(name);
          changed = true;
        }
      }
      if (!changed) continue;
      try {
        await repository.save(memory.withEncounters(encounters));
      } on StateError {
        // Purged since we read it: nothing left to rename.
      }
    }
  }

  bool _belongs(
    PlaceGroup group,
    Set<String> targets,
    Memory memory,
    String place,
    String photoFileName,
  ) {
    final groupName = group.name;
    // An unknown place's own encounters, unless named since we looked.
    return groupName == null
        ? targets.contains('${memory.id}/$photoFileName') &&
            place.trim().isEmpty
        : MeetingFinder.samePlace(place, groupName);
  }
}
