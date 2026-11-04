import 'package:flutter/foundation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'filter_kind.dart';

/// One filter on the list, with an id that keys its row, so a text field
/// keeps its state when a row above it is removed.
typedef ListFilter = ({int id, FilterCondition condition});

/// The main list's filters, its order and an optional note above them
/// ("Add their names while you remember."). Not saved: a restart shows
/// everyone, newest first. A notice or a group photo sets them with
/// [show].
class ListFilters extends ChangeNotifier {
  final List<ListFilter> _filters = [];
  int _nextId = 0;
  String? _note;
  PeopleOrder _order = const PeopleOrder();

  /// The filter just added, whose text field takes the keyboard.
  int? added;

  List<ListFilter> get filters => List.unmodifiable(_filters);
  String? get note => _note;
  PeopleOrder get order => _order;

  /// The filters that narrow the list (a blank one does not).
  List<FilterCondition> get active => [
    for (final f in _filters)
      if (!f.condition.isBlank) f.condition,
  ];

  bool get isFiltered => active.isNotEmpty;

  /// [people] narrowed by every filter, in [order].
  List<Memory> apply(List<Memory> people) => _order.apply(
    MemoryFilter([for (final f in _filters) f.condition]).apply(people),
  );

  /// Replaces the filters (and any note) with [conditions].
  void show(List<FilterCondition> conditions, {String? note}) {
    _filters
      ..clear()
      ..addAll([for (final c in conditions) (id: _nextId++, condition: c)]);
    _note = note;
    added = null;
    notifyListeners();
  }

  void add(FilterKind kind) {
    added = _nextId++;
    _filters.add((id: added!, condition: kind.blank()));
    _changedByHand();
  }

  void change(int id, FilterCondition condition) {
    final i = _filters.indexWhere((f) => f.id == id);
    if (i < 0) return;
    _filters[i] = (id: id, condition: condition);
    _changedByHand();
  }

  void remove(int id) {
    _filters.removeWhere((f) => f.id == id);
    _changedByHand();
  }

  void clear() {
    _filters.clear();
    _changedByHand();
  }

  /// Sorts by [sort]; the same sort again reverses it.
  void sortBy(PersonSort sort) {
    _order = _order.choose(sort);
    notifyListeners();
  }

  /// A note belongs to the filters it came with; Fred's own change ends it.
  void _changedByHand() {
    _note = null;
    notifyListeners();
  }
}
