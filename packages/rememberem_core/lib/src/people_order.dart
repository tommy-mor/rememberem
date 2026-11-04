import 'memory.dart';
import 'memory_field.dart';

/// What the list sorts people by.
enum PersonSort {
  firstName('First name'),
  lastName('Last name'),
  date('Date met');

  const PersonSort(this.label);

  final String label;
}

/// An order for the list: by [sort], [reversed] or not. Names run A to Z
/// and dates newest first, unless reversed. People with no name come last
/// either way.
class PeopleOrder {
  const PeopleOrder([this.sort = PersonSort.date, this.reversed = false]);

  final PersonSort sort;
  final bool reversed;

  /// Choosing the current sort again reverses it; another sort starts
  /// forwards.
  PeopleOrder choose(PersonSort chosen) =>
      chosen == sort ? PeopleOrder(sort, !reversed) : PeopleOrder(chosen);

  List<Memory> apply(List<Memory> people) {
    final named = <Memory>[];
    final unnamed = <Memory>[];
    for (final m in people) {
      (m.field(MemoryField.name).trim().isEmpty ? unnamed : named).add(m);
    }
    int compare(Memory a, Memory b) {
      final c = switch (sort) {
        PersonSort.firstName => _byName(a, b, (w) => w.first),
        PersonSort.lastName => _byName(a, b, (w) => w.last),
        PersonSort.date => b.latest.capturedAt.compareTo(a.latest.capturedAt),
      };
      // Ties break on id, so reversing is an exact mirror.
      final tie = c != 0 ? c : a.id.compareTo(b.id);
      return reversed ? -tie : tie;
    }

    // Unnamed people keep the date order among themselves.
    int byDate(Memory a, Memory b) {
      final c = b.latest.capturedAt.compareTo(a.latest.capturedAt);
      final tie = c != 0 ? c : a.id.compareTo(b.id);
      return reversed && sort == PersonSort.date ? -tie : tie;
    }

    return [...named..sort(compare), ...unnamed..sort(byDate)];
  }

  static int _byName(
    Memory a,
    Memory b,
    String Function(List<String> words) part,
  ) {
    final c = _key(a, part).compareTo(_key(b, part));
    return c != 0 ? c : _full(a).compareTo(_full(b));
  }

  static String _key(Memory m, String Function(List<String> words) part) =>
      part(_full(m).split(RegExp(r'\s+')));

  static String _full(Memory m) =>
      m.field(MemoryField.name).trim().toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is PeopleOrder && other.sort == sort && other.reversed == reversed;

  @override
  int get hashCode => Object.hash(sort, reversed);
}
