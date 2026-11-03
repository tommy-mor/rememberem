import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../memories/person_card_route.dart';

import 'place_row.dart';
import 'places_map.dart';
import 'rename_place_dialog.dart';

/// Every place Fred has met people: a list on top, a map below. Picking a
/// place in either selects it, centres the map on it and lists its people.
/// Places can be renamed, or named if unknown.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({
    super.key,
    required this.services,
    required this.routeObserver,
  });

  final AppServices services;
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> with RouteAware {
  MemoryRepository get _repository => widget.services.repository;
  final _scroll = ScrollController();
  List<PlaceGroup>? _groups;
  PlaceGroup? _selected;
  Object? _error;
  int _reloadGen = 0;

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
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _reload();

  Future<void> _reload() async {
    final gen = ++_reloadGen;
    try {
      final groups = PlaceBook.from(await _repository.all()).groups;
      if (!mounted || gen != _reloadGen) return;
      setState(() {
        _groups = groups;
        _error = null;
        _selected = _sameGroup(_selected, groups);
      });
    } catch (error) {
      if (mounted && gen == _reloadGen) setState(() => _error = error);
    }
  }

  /// The group in [groups] that is [old]: same name, or for an unknown
  /// place, the one holding the same newest encounter.
  PlaceGroup? _sameGroup(PlaceGroup? old, List<PlaceGroup> groups) {
    if (old == null) return null;
    final name = old.name;
    if (name != null) return groups.where((g) => g.name == name).firstOrNull;
    final (memory, encounter) = old.members.first;
    return groups
        .where(
          (g) =>
              g.name == null &&
              g.members.any(
                (m) =>
                    m.$1.id == memory.id &&
                    m.$2.photoFileName == encounter.photoFileName,
              ),
        )
        .firstOrNull;
  }

  void _openPerson(Memory person) =>
      Navigator.of(context)
          .push(PersonCardRoute(services: widget.services, memory: person));

  void _select(PlaceGroup group) {
    final groups = _groups;
    if (groups == null) return;
    setState(() => _selected = group);
    final index = groups.indexOf(group);
    if (index < 0 || !_scroll.hasClients) return;
    // Only the selected row is expanded, so every row above it is
    // collapsed and the offset is exact.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(index));
  }

  /// The list is lazy, so the scroll limit is only an estimate until the
  /// selected row has been laid out: scroll, then correct once it has.
  Future<void> _scrollTo(int index, {bool settled = false}) async {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = (index * PlaceRow.collapsedExtent).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if ((position.pixels - target).abs() < 1) return;
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (!settled && mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollTo(index, settled: true),
      );
    }
  }

  Future<void> _rename(PlaceGroup group) async {
    final groups = _groups ?? [];
    var affected = group.people.length;
    final name = group.name;
    if (name != null) {
      try {
        final trashed = await _repository.trashed();
        affected += trashed
            .where(
              (m) => m.encounters.any(
                (e) => MeetingFinder.samePlace(e.place, name),
              ),
            )
            .length;
      } catch (_) {
        // The count is only advice.
      }
    }
    if (!mounted) return;
    final alerts = widget.services.placeAlerts;
    final result = await RenamePlaceDialog.show(
      context,
      group: group,
      otherNames: [
        for (final g in groups)
          if (g != group && g.name != null) g.name!,
      ],
      peopleAffected: affected,
      alertSettings: alerts?.settings.value,
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final unchanged =
        name != null && MeetingFinder.samePlace(name, result.name);
    try {
      if (!unchanged) {
        await PlaceRenamer(_repository).rename(group, result.name);
      }
      // Only once the rename has worked, so a failure keeps the old choice.
      await alerts?.renamed(name ?? result.name, result.name, result.notify);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not rename the place. Try again.')),
      );
    }
    _selected = null;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load places.'),
            TextButton(onPressed: _reload, child: const Text('Retry')),
          ],
        ),
      );
    }
    final groups = _groups;
    if (groups == null) return const Center(child: CircularProgressIndicator());
    if (groups.isEmpty) return const Center(child: Text('No places yet.'));
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return PlaceRow(
                group: group,
                expanded: group == _selected,
                onTap: () => _select(group),
                onRename: () => _rename(group),
                onOpenPerson: _openPerson,
                repository: _repository,
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PlacesMap(
            groups: groups,
            selected: _selected,
            onSelect: _select,
            streetMaps: widget.services.settings.value.streetMaps,
            links: widget.services.links,
          ),
        ),
      ],
    );
  }
}
