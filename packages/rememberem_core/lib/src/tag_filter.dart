import 'detail.dart';
import 'detail_kind.dart';
import 'detail_type_catalog.dart';
import 'filter_condition.dart';
import 'memory.dart';

/// People with the tag [name], ignoring case and surrounding space.
class TagFilter implements FilterCondition {
  const TagFilter([this.name]);

  final String? name;

  @override
  bool get isBlank => (name?.trim() ?? '').isEmpty;

  @override
  bool matches(Memory memory) => isBlank || detailsIn(memory).isNotEmpty;

  /// The person's tags of this type.
  List<Detail> detailsIn(Memory memory) {
    if (isBlank) return const [];
    final key = DetailTypeCatalog.normalizeKey(name!);
    return [
      for (final d in memory.details)
        if (d.kind == DetailKind.tag &&
            DetailTypeCatalog.normalizeKey(d.label ?? '') == key)
          d,
    ];
  }
}
