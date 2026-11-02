import 'encounter.dart';
import 'memory.dart';
import 'place_finder.dart';
import 'place_group.dart';

/// Every place Fred has met people, derived from their encounters (there
/// is no separate store). Named places group by trimmed name; unnamed
/// spots group with the newest spot within [radiusMeters] of them.
class PlaceBook {
  PlaceBook._(this.groups);

  factory PlaceBook.from(
    List<Memory> people, {
    double radiusMeters = PlaceFinder.defaultRadiusMeters,
  }) {
    final all = [
      for (final memory in people)
        for (final encounter in memory.encounters) (memory, encounter),
    ]..sort((a, b) => Encounter.newestFirst(a.$2, b.$2));
    final named = <String, List<(Memory, Encounter)>>{};
    final clusters = <List<(Memory, Encounter)>>[];
    final nowhere = <(Memory, Encounter)>[];
    for (final member in all) {
      final (_, encounter) = member;
      final name = encounter.place.trim();
      final location = encounter.location;
      if (name.isNotEmpty) {
        named.putIfAbsent(name, () => []).add(member);
      } else if (location == null) {
        nowhere.add(member);
      } else {
        // Join the first cluster whose anchor (its newest spot) is close,
        // so a chain of spots cannot grow a cluster without limit.
        final cluster = clusters.where((c) {
          final anchor = c.first.$2.location!;
          return anchor.distanceTo(location) <= radiusMeters; // NaN: no
        }).firstOrNull;
        cluster == null ? clusters.add([member]) : cluster.add(member);
      }
    }
    final groups = [
      for (final entry in named.entries)
        PlaceGroup(name: entry.key, members: entry.value),
      for (final cluster in clusters) PlaceGroup(name: null, members: cluster),
      if (nowhere.isNotEmpty) PlaceGroup(name: null, members: nowhere),
    ]..sort((a, b) {
        final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
        if (byLabel != 0) return byLabel;
        final exact = a.label.compareTo(b.label);
        return exact != 0 ? exact : b.newest.compareTo(a.newest);
      });
    return PlaceBook._(groups);
  }

  final List<PlaceGroup> groups;
}
