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
  bool matches(Memory memory) {
    if (isBlank) return true;
    final key = DetailTypeCatalog.normalizeKey(name!);
    return memory.details.any(
      (d) =>
          d.kind == DetailKind.tag &&
          DetailTypeCatalog.normalizeKey(d.label ?? '') == key,
    );
  }
}
