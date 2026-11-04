import 'detail.dart';
import 'detail_kind.dart';
import 'detail_prompt.dart';

/// A detail in one line, as a collapsed card and a filtered list show it:
/// its data first, then its description. "Brother: Ann - helps at the
/// cafe", "Wedding: 3 Jun 2010 - at the lake", "3 Mar 2026 · Park - ran",
/// "Relatives · Park - text", or just the text for a fact.
class DetailSummary {
  const DetailSummary._();

  /// The parts shown before a detail's text: a happening's date and place,
  /// a relationship's type and person, an anniversary's type and date, a
  /// tag's type, place and date; only those it has.
  static List<String> prefixParts(
    Detail detail,
    String? Function(String id) nameOf,
  ) {
    final d = detail;
    final label = _capitalised(d.label?.trim() ?? '');
    final target = d.targetId;
    final parts = switch (d.kind) {
      DetailKind.fact => const <String>[],
      DetailKind.happening => [
          DetailPrompt.date(d.at.toLocal()),
          d.place?.trim() ?? '',
        ],
      DetailKind.relationship => [
          label,
          if (target != null) nameOf(target) ?? DetailPrompt.someoneRemoved,
        ],
      DetailKind.anniversary => [
          label,
          if (d.eventDate case final day?) DetailPrompt.date(day),
        ],
      DetailKind.tag => DetailPrompt.tagParts(d),
    };
    return parts.where((p) => p.isNotEmpty).toList();
  }

  /// What goes before the text: "Brother: Ann - ", "Wedding: 3 Jun 2010 - ",
  /// "3 Mar 2026 · Park - ", "Relatives · Park - "; null with no parts.
  static String? prefix(Detail detail, String? Function(String id) nameOf) {
    final parts = prefixParts(detail, nameOf);
    if (parts.isEmpty) return null;
    final joined = detail.kind == DetailKind.relationship ||
            detail.kind == DetailKind.anniversary
        ? parts.join(': ')
        : parts.join(' · ');
    return '$joined - ';
  }

  /// The whole line: [prefix] then the text. Without text, just the parts
  /// ("Brother: Ann"); with neither, empty.
  static String lineFor(Detail detail, String? Function(String id) nameOf) {
    final text = detail.text.trim();
    final before = prefix(detail, nameOf);
    if (before == null) return text;
    return text.isEmpty
        ? before.substring(0, before.length - 3)
        : '$before$text';
  }

  /// Where a list of mixed kinds names the kind first: "Fact · ",
  /// "Happening · ", "Tag · ". A relationship or anniversary line says
  /// what it is already.
  static String kindHead(Detail detail) => switch (detail.kind) {
        DetailKind.relationship || DetailKind.anniversary => '',
        _ => '${detail.kind.label} · ',
      };

  /// How a row's buttons name it: its kind and parts, so a screen reader
  /// can tell rows of one kind apart.
  static String spokenName(
    Detail detail,
    String? Function(String id) nameOf,
  ) =>
      [detail.kind.label, ...prefixParts(detail, nameOf)].join(' ');

  static String _capitalised(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
