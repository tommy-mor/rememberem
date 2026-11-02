import 'detail.dart';
import 'detail_kind.dart';
import 'detail_type_catalog.dart';

/// How a [Detail] reads, the same on the person card and in practice: a
/// small caption (its kind), a prefix built from its date, place, type and
/// person, and the description.
class DetailPrompt {
  /// [nameOf] gives the shown name of an active person, or null for anyone
  /// trashed or gone.
  const DetailPrompt(this.detail, this.nameOf);

  final Detail detail;
  final String? Function(String id) nameOf;

  /// Shown for a relationship whose other person is trashed or gone.
  static const someoneRemoved = 'someone removed';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// A calendar day as "3 Jun 2010".
  static String date(DateTime day) =>
      '${day.day} ${_months[day.month - 1]} ${day.year}';

  String get caption => detail.kind.label;

  /// The other person's name, or [someoneRemoved].
  String get targetName {
    final id = detail.targetId;
    return (id == null ? null : nameOf(id)) ?? someoneRemoved;
  }

  /// What goes before the description: "27 Oct 2026, Park" for a
  /// happening, "My boss is Jill" for a relationship, "Wedding, 3 Jun 2010"
  /// for an anniversary, nothing for a fact.
  String get prefix {
    final d = detail;
    switch (d.kind) {
      case DetailKind.fact:
        return '';
      case DetailKind.happening:
        final place = d.place?.trim() ?? '';
        final day = date(d.at.toLocal());
        return place.isEmpty ? day : '$day, $place';
      case DetailKind.relationship:
        final label = d.label?.trim() ?? '';
        return label.isEmpty
            ? 'Relationship with $targetName'
            : 'My $label is $targetName';
      case DetailKind.anniversary:
        final label = d.label?.trim() ?? '';
        final when = d.eventDate;
        return [
          if (label.isNotEmpty) _capitalised(label) else 'Anniversary',
          if (when != null) date(when),
        ].join(', ');
    }
  }

  /// The prefix and the description together, as one line of text.
  String get full {
    final text = detail.text.trim();
    final prefix = this.prefix;
    if (prefix.isEmpty) return text;
    return text.isEmpty ? prefix : '$prefix: $text';
  }

  /// Equal for two details that read the same, so a quiz can tell when
  /// more than one person would be a right answer.
  String get equivalenceKey =>
      '${detail.kind.name}|${DetailTypeCatalog.normalizeKey(full)}';

  static String _capitalised(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
