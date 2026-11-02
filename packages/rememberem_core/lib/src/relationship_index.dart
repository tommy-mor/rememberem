import 'detail_kind.dart';
import 'memory.dart';
import 'relationship_link.dart';

/// Everyone a person is related to, in both directions.
class RelationshipIndex {
  const RelationshipIndex._();

  /// The links of [person] (its current copy, which wins over any copy in
  /// [active]) among the [active] people: its own relationships first, in
  /// order, then those on other records that point at it. People not in
  /// [active] (trashed or gone) are left out, as is [person] itself.
  static List<RelationshipLink> of(Memory person, List<Memory> active) {
    final others = {
      for (final m in active)
        if (m.id != person.id && m.trashedAt == null) m.id: m,
    };
    return [
      for (final d in person.details)
        if (d.kind == DetailKind.relationship)
          if (others[d.targetId] case final other?)
            RelationshipLink(
              person: other,
              label: d.label?.trim() ?? '',
              outgoing: true,
            ),
      for (final other in others.values)
        for (final d in other.details)
          if (d.kind == DetailKind.relationship && d.targetId == person.id)
            RelationshipLink(
              person: other,
              label: d.label?.trim() ?? '',
              outgoing: false,
            ),
    ];
  }
}
