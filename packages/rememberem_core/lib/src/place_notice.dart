import 'meeting_finder.dart';
import 'memory.dart';
import 'memory_field.dart';

/// The notice on arriving at a place: who Fred has met there. A place is
/// known to the phone's geofencing only by an opaque id ([fenceId]), so
/// no name is ever in the plugin's storage, its logs, or a tap's payload.
class PlaceNotice {
  const PlaceNotice._();

  /// A place's notice shows at most once in this long.
  static const quiet = Duration(hours: 12);

  /// At most this many people are named; the rest are counted.
  static const most = 3;

  static const _prefix = 'arrival:';
  static final _pattern = RegExp(r'^arrival:(f[0-9a-f]{8})$');

  /// The opaque id for a place: a hash of its trimmed name (places are
  /// told apart by case, as everywhere else).
  static String fenceId(String place) {
    var hash = 0x811c9dc5; // FNV-1a, 32 bits
    for (final unit in place.trim().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'f${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// Of [places], the one whose id is [id], or null.
  static String? placeFor(String id, Iterable<String> places) {
    for (final place in places) {
      if (fenceId(place) == id) return place;
    }
    return null;
  }

  static String wireId(String fenceId) => '$_prefix$fenceId';

  /// The fence id a tapped notice was for, or null for anything else
  /// (payloads come from outside the app and are untrusted).
  static String? fenceFromWire(String? wireId) =>
      _pattern.firstMatch(wireId ?? '')?[1];

  static String title(String place) => 'At ${place.trim()}';

  /// Who Fred has met at [place] among [active]: "You've met Ann Lee, Bo
  /// and 2 more here." Null if no one, so no notice.
  static String? textFor(List<Memory> active, String place) {
    final names = <String>[];
    var unnamed = 0;
    for (final person in active) {
      final met =
          person.encounters.any((e) => MeetingFinder.samePlace(e.place, place));
      if (!met) continue;
      final name = person.field(MemoryField.name).trim();
      name.isEmpty ? unnamed++ : names.add(name);
    }
    if (names.isEmpty && unnamed == 0) return null;
    final shown = names.take(most).toList();
    final rest = names.length - shown.length + unnamed;
    if (shown.isEmpty) {
      return rest == 1
          ? "You've met someone here."
          : "You've met $rest people here.";
    }
    if (rest == 0) {
      final list = shown.length == 1
          ? shown.single
          : '${shown.take(shown.length - 1).join(', ')} and ${shown.last}';
      return "You've met $list here.";
    }
    return "You've met ${shown.join(', ')} and $rest more here.";
  }

  /// Whether a place last noticed at [last] may be noticed at [now].
  static bool due(DateTime? last, DateTime now) =>
      last == null || !now.isBefore(last.add(quiet));
}
