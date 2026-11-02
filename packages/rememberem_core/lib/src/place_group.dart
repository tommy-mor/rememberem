import 'encounter.dart';
import 'geo_point.dart';
import 'memory.dart';

/// One place on the Places page: every encounter there, with the person
/// met. Unnamed places are a cluster of nearby spots (or the spots with no
/// location at all).
class PlaceGroup {
  PlaceGroup({required this.name, required this.members});

  /// Trimmed name, or null for an unnamed ("unknown") place.
  final String? name;

  /// Newest first.
  final List<(Memory, Encounter)> members;

  String get label => name ?? 'unknown';

  /// Where to draw it: the newest member that has a location, or null.
  GeoPoint? get marker {
    for (final (_, encounter) in members) {
      final location = encounter.location;
      if (location != null) return location;
    }
    return null;
  }

  DateTime get newest => members.first.$2.capturedAt;

  /// Each person met here once, in member order.
  List<Memory> get people {
    final seen = <String>{};
    return [
      for (final (memory, _) in members)
        if (seen.add(memory.id)) memory,
    ];
  }
}
