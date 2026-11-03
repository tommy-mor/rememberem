import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import 'filter_kind.dart';
import 'filter_row.dart';
import 'memory_tile.dart';
import 'person_card_route.dart';

/// The Filter List: everyone, narrowed by any number of filters (all must
/// match), then open a match. Nothing here is saved, not even the filters.
class FilterListScreen extends StatefulWidget {
  const FilterListScreen({
    super.key,
    required this.services,
    required this.routeObserver,
    this.initialFilters = const [],
    this.note,
  });

  final AppServices services;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final List<FilterCondition> initialFilters;

  /// A line shown above the filters, such as a reminder to add names.
  final String? note;

  @override
  State<FilterListScreen> createState() => _FilterListScreenState();
}

class _FilterListScreenState extends State<FilterListScreen> with RouteAware {
  List<Memory>? _people;
  Object? _error;
  int _reloadGen = 0;

  /// Each filter with an id that keys its row, so a text field keeps its
  /// state when a row above it is removed.
  late final List<({int id, FilterCondition condition})> _filters = [
    for (final (i, c) in widget.initialFilters.indexed) (id: i, condition: c),
  ];
  late int _nextId = _filters.length;
  int? _added;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) widget.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Back from a person's card: show their edits, trash or merge.
  @override
  void didPopNext() => _reload();

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    try {
      final people = await widget.services.repository.all();
      if (mounted && gen == _reloadGen) {
        setState(() {
          _people = people;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && gen == _reloadGen) setState(() => _error = error);
    }
  }

  void _add(FilterKind kind) => setState(() {
    _added = _nextId++;
    _filters.add((id: _added!, condition: kind.blank()));
  });

  void _change(int id, FilterCondition condition) => setState(() {
    final i = _filters.indexWhere((f) => f.id == id);
    if (i >= 0) _filters[i] = (id: id, condition: condition);
  });

  void _remove(int id) =>
      setState(() => _filters.removeWhere((f) => f.id == id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filter List')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load people.'),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }
    final people = _people;
    if (people == null) return const Center(child: CircularProgressIndicator());
    final matches = MemoryFilter([for (final f in _filters) f.condition])
        .apply(people);
    final places = MemoryFilter.places(people);
    final meetings = MemoryFilter.meetings(people);
    final tags = DetailTypeCatalog.labels(DetailKind.tag, people);
    final note = widget.note;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(
            children: [
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(note),
                ),
              for (final f in _filters)
                FilterRow(
                  key: ValueKey(f.id),
                  condition: f.condition,
                  places: places,
                  meetings: meetings,
                  tags: tags,
                  autofocus: f.id == _added,
                  onChanged: (c) => _change(f.id, c),
                  onRemove: () => _remove(f.id),
                ),
              Row(
                children: [
                  PopupMenuButton<FilterKind>(
                    tooltip: 'Add filter',
                    onSelected: _add,
                    itemBuilder: (_) => [
                      for (final kind in FilterKind.values)
                        PopupMenuItem(value: kind, child: Text(kind.label)),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('Add filter'),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    matches.length == 1
                        ? '1 person'
                        : '${matches.length} people',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (matches.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No one matches.')),
          )
        else
          SliverList.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) => MemoryTile(
              memory: matches[index],
              photo: widget.services.repository.photoFile(matches[index]),
              onTap: () => Navigator.of(context).push(
                PersonCardRoute(
                  services: widget.services,
                  memory: matches[index],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
