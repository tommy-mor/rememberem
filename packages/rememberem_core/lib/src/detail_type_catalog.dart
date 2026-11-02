import 'detail_kind.dart';
import 'memory.dart';

/// The relationship and anniversary types to suggest: the built-in ones,
/// then any Fred has typed that some person (active or in the trash) still
/// uses. Nothing is stored, so a type no one uses is simply gone.
class DetailTypeCatalog {
  const DetailTypeCatalog._();

  static const relationshipDefaults = [
    'coworker',
    'partner',
    'spouse',
    'friend',
    'boss',
  ];

  static const anniversaryDefaults = [
    'first met',
    'wedding',
    'birthday',
    'started work',
    'lost someone',
  ];

  /// Types that differ only in case or surrounding space are one type.
  static String normalizeKey(String label) => label.trim().toLowerCase();

  /// The types to offer for [kind] (relationship or anniversary): the
  /// defaults, then custom ones in first-seen spelling.
  static List<String> labels(DetailKind kind, Iterable<Memory> people) {
    final defaults = switch (kind) {
      DetailKind.relationship => relationshipDefaults,
      DetailKind.anniversary => anniversaryDefaults,
      DetailKind.fact || DetailKind.happening => const <String>[],
    };
    final seen = {for (final d in defaults) normalizeKey(d)};
    final custom = <String>[];
    for (final person in people) {
      for (final detail in person.details) {
        if (detail.kind != kind) continue;
        final label = detail.label?.trim() ?? '';
        if (label.isEmpty) continue;
        if (seen.add(normalizeKey(label))) custom.add(label);
      }
    }
    return [...defaults, ...custom];
  }
}
