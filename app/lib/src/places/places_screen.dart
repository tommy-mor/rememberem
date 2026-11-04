import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/home_button.dart';
import '../memories/person_card_route.dart';

import '../settings/units.dart';
import 'confirm_rename_dialog.dart';
import 'place_row.dart';
import 'places_map.dart';
import 'radius_panel.dart';

/// Every place Fred has met people: a list on top, a map below. Picking a
/// place in either selects it, centres the map on it and lists its people.
/// Places are renamed, or named if unknown, in the list itself, and a
/// named place's radius is adjusted on a slider over the map.
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

  /// The place whose radius panel is open, the radius being dragged (null
  /// once let go), and whether the map should fit it exactly.
  PlaceGroup? _adjusting;
  double? _draft;
  bool _settled = true;
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
        _adjusting = _sameGroup(_adjusting, groups);
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
    final rowHeight = MediaQuery.textScalerOf(context)
        .scale(PlaceRow.collapsedExtent);
    final target = (index * rowHeight).clamp(0.0, position.maxScrollExtent);
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

  /// Renames [group] to [newName]; true if it was renamed. A known place
  /// asks first; an unknown one is just named. Its own radius moves with
  /// it once the rename has worked.
  Future<bool> _rename(PlaceGroup group, String newName) async {
    final groups = _groups ?? [];
    final name = group.name;
    final merges = groups.any(
      (g) =>
          g != group &&
          g.name != null &&
          MeetingFinder.samePlace(g.name!, newName),
    );
    if (name != null) {
      var affected = group.people.length;
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
      if (!mounted) return false;
      final confirmed = await ConfirmRenameDialog.show(
        context,
        from: name,
        to: newName,
        peopleAffected: affected,
        merges: merges,
      );
      if (!confirmed || !mounted) return false;
    }
    final messenger = ScaffoldMessenger.of(context);
    final settings = widget.services.settings;
    try {
      await PlaceRenamer(_repository).rename(group, newName);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not rename the place. Try again.')),
      );
      await _reload();
      return false;
    }
    // A radius left under the new name by a place now gone is dropped; a
    // place merged into keeps its own.
    var updated = settings.value;
    if (!merges) updated = updated.withPlaceRadius(newName, null);
    if (name != null) updated = updated.withPlaceRenamed(name, newName);
    if (updated != settings.value) await settings.update(updated);
    _selected = null;
    _adjusting = null;
    await _reload();
    return true;
  }

  /// Opens the radius panel for [group] (selecting it).
  void _adjust(PlaceGroup group) {
    _select(group);
    setState(() {
      _adjusting = group;
      _draft = null;
      _settled = true;
    });
  }

  /// The radius on show for [place]: the one being dragged, else saved.
  double _radiusFor(String place) {
    final adjusting = _adjusting?.name;
    final draft = _draft;
    if (draft != null && adjusting == place) return draft;
    return widget.services.settings.value.radiusFor(place);
  }

  void _drag(double meters) => setState(() {
    _draft = meters;
    _settled = false;
  });

  void _settle(double? meters) {
    final name = _adjusting?.name;
    if (name == null) return;
    final settings = widget.services.settings;
    settings.update(settings.value.withPlaceRadius(name, meters));
    setState(() {
      _draft = null;
      _settled = true;
    });
  }

  /// The radius being adjusted, for the map to keep in view.
  ({GeoPoint at, double meters, bool settled})? get _focus {
    final group = _adjusting;
    final at = group?.marker;
    final name = group?.name;
    if (at == null || name == null) return null;
    return (at: at, meters: _radiusFor(name), settled: _settled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Places'),
        actions: const [HomeButton()],
      ),
      body: _body(),
    );
  }

  Widget _body() => ValueListenableBuilder<AppSettings>(
    valueListenable: widget.services.settings,
    builder: (context, settings, _) => _content(settings),
  );

  Widget _content(AppSettings settings) {
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
              final name = group.name;
              return PlaceRow(
                // Keyed by place, so a name being typed stays with it.
                key: ValueKey(
                  name ??
                      'unknown ${group.members.first.$1.id}/'
                          '${group.members.first.$2.photoFileName}',
                ),
                group: group,
                expanded: group == _selected,
                onTap: () => _select(group),
                onRename: (newName) => _rename(group, newName),
                onOpenPerson: _openPerson,
                repository: _repository,
                radius: name == null
                    ? null
                    : Units.distance(settings, _radiusFor(name)),
                onRadius: name == null ? null : () => _adjust(group),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: PlacesMap(
                  groups: groups,
                  selected: _selected,
                  onSelect: _select,
                  streetMaps: settings.streetMaps,
                  links: widget.services.links,
                  radiusFor: _radiusFor,
                  focus: _focus,
                ),
              ),
              if (_adjusting case PlaceGroup(:final name?))
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RadiusPanel(
                    place: name,
                    meters: _radiusFor(name),
                    format: (m) => Units.distance(settings, m),
                    onChanged: _drag,
                    onSettled: _settle,
                    onUseDefault: () => _settle(null),
                    onDone: () => setState(() => _adjusting = null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
