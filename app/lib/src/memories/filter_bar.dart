import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'filter_kind.dart';
import 'filter_row.dart';
import 'list_filters.dart';

/// Above the list: any note, the filters, then "Add filter", "Sort", how
/// many people show, and "Clear all" while filters are on.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.filters,
    required this.people,
    required this.shown,
  });

  final ListFilters filters;

  /// Everyone, for the place, meeting and tag choices.
  final List<Memory> people;

  /// How many people the filters leave.
  final int shown;

  /// Said while a date range is on, since facts and relationships have no
  /// date to match.
  static const dateHint =
      'Dates match photos, happenings, tags and anniversaries.';

  @override
  Widget build(BuildContext context) {
    final note = filters.note;
    final small = Theme.of(context).textTheme.bodySmall;
    final places = MemoryFilter.places(people);
    final meetings = MemoryFilter.meetings(people);
    final tags = DetailTypeCatalog.labels(DetailKind.tag, people);
    final dated = filters.active.any((c) => c is DateRangeFilter);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(note),
            ),
          for (final f in filters.filters)
            FilterRow(
              key: ValueKey(f.id),
              condition: f.condition,
              places: places,
              meetings: meetings,
              tags: tags,
              openNow: f.id == filters.added,
              onOpened: () => filters.consumeAdded(f.id),
              onChanged: (c) => filters.change(f.id, c),
              onRemove: () => filters.remove(f.id),
            ),
          if (dated) Text(dateHint, style: small),
          // Wraps rather than overflowing with large text.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              PopupMenuButton<FilterKind>(
                tooltip: 'Add filter',
                onSelected: filters.add,
                itemBuilder: (_) => [
                  for (final kind in FilterKind.values)
                    PopupMenuItem(value: kind, child: Text(kind.label)),
                ],
                child: _menuLabel(Icons.filter_list, 'Add filter'),
              ),
              _sortMenu(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shown == 1 ? '1 person' : '$shown people', style: small),
                  if (filters.filters.isNotEmpty)
                    TextButton(
                      onPressed: filters.clear,
                      child: const Text('Clear all'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Which way a sort runs, in words.
  static String direction(PeopleOrder order) {
    final names = order.sort != PersonSort.date;
    return switch ((names, order.reversed)) {
      (true, false) => 'A to Z',
      (true, true) => 'Z to A',
      (false, false) => 'newest first',
      (false, true) => 'oldest first',
    };
  }

  Widget _sortMenu() {
    final order = filters.order;
    final arrow = order.reversed ? Icons.arrow_upward : Icons.arrow_downward;
    return PopupMenuButton<PersonSort>(
      tooltip: 'Sort by ${order.sort.label}, ${direction(order)}',
      onSelected: filters.sortBy,
      itemBuilder: (_) => [
        for (final sort in PersonSort.values)
          PopupMenuItem(
            value: sort,
            child: Semantics(
              selected: sort == order.sort,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: sort == order.sort ? Icon(arrow, size: 18) : null,
                  ),
                  Flexible(
                    child: Text(
                      sort == order.sort
                          ? '${sort.label} (${direction(order)})'
                          : sort.label,
                      semanticsLabel: sort == order.sort
                          ? '${sort.label}, ${direction(order)}. '
                                'Choose again to reverse.'
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      child: _menuLabel(Icons.sort, order.sort.label, trailing: arrow),
    );
  }

  /// An icon and a word, the look of the bar's menus.
  static Widget _menuLabel(IconData icon, String text, {IconData? trailing}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(width: 6),
            Text(text),
            if (trailing != null) Icon(trailing, size: 16),
          ],
        ),
      );
}
