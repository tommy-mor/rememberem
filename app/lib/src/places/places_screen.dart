import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/home_button.dart';
import '../memories/person_card_route.dart';

import '../settings/units.dart';
import 'confirm_rename_dialog.dart';
import 'place_row.dart';
import 'places_map.dart';
import 'radius_slider.dart';

/// Every place Fred has met people: a list on top, a map below. Picking a
/// place in either selects it, centres the map on it and lists its people.
/// Places are renamed, or named if unknown, in the list itself, and a
/// named place's radius is slid on its row. On the map, a double tap
/// zooms to a place and a long press moves a named one.
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

  /// The place whose radius is being slid, the radius being dragged (null
  /// once let go), and whether the map should fit it exactly.
  PlaceGroup? _adjusting;
  double? _draft;
  bool _settled = true;

  /// Bumped to centre the map on the selected place again.
  int _centreTick = 0;

  /// A double-tapped place to fit, its radius a fifth of the map.
  ({GeoPoint at, double meters, int tick})? _zoom;
  int _zoomTick = 0;

  /// The place being moved, and where the map's middle is.
  PlaceGroup? _moving;
  GeoPoint? _moveTo;

  /// Set while a move is being saved, so a second tap does nothing.
  bool _savingMove = false;
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
      final groups = PlaceBook.from(
        await _repository.all(),
        spots: widget.services.settings.value.placeSpots,
      ).groups;
      if (!mounted || gen != _reloadGen) return;
      setState(() {
        _groups = groups;
        _error = null;
        _selected = _sameGroup(_selected, groups);
        _adjusting = _sameGroup(_adjusting, groups);
        _moving = _sameGroup(_moving, groups);
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
    // While a place is being moved, the map is Fred's to drag.
    if (groups == null || _moving != null) return;
    setState(() {
      _selected = group;
      _centreTick++;
    });
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
    if (!merges) {
      updated = updated
          .withPlaceRadius(newName, null)
          .withPlaceSpot(newName, null);
    }
    if (name != null) updated = updated.withPlaceRenamed(name, newName);
    if (updated != settings.value) await settings.update(updated);
    _selected = null;
    _adjusting = null;
    _moving = null;
    await _reload();
    return true;
  }

  /// Zooms the map to [group] (selecting it), so its radius is a fifth
  /// of the map: the fitted square is 2.5 radii each side of it.
  void _zoomTo(PlaceGroup group) {
    final at = group.marker;
    if (at == null || _moving != null) return;
    _select(group);
    final meters = group.name == null
        ? widget.services.settings.value.placeFinder.radiusMeters
        : _radiusFor(group.name!);
    setState(() => _zoom = (at: at, meters: meters * 2.5, tick: ++_zoomTick));
  }

  /// Starts moving [group]: the map centres on it and Fred drags the map
  /// under a fixed pin.
  void _startMove(PlaceGroup group) {
    final name = group.name;
    if (name == null || group.marker == null) return;
    _select(group);
    setState(() {
      _adjusting = null;
      _moving = group;
      _moveTo = group.marker;
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Moving $name. Drag the map, then choose Move here.',
      Directionality.of(context),
    );
  }

  /// Ends moving; with [save], the place's spot is kept, and moving mode
  /// stays until the list shows it there (no flash of the old spot).
  Future<void> _finishMove({required bool save}) async {
    if (_savingMove) return;
    final name = _moving?.name;
    final at = _moveTo;
    // Not dragged: nothing to keep.
    if (save && name != null && at != null && at != _moving?.marker) {
      _savingMove = true;
      try {
        final settings = widget.services.settings;
        await settings.update(settings.value.withPlaceSpot(name, at));
        await _reload();
      } finally {
        _savingMove = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _moving = null;
      _moveTo = null;
    });
  }

  /// Opens the radius slider for [group] (selecting it).
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

  /// Saves the radius chosen. One within 3% of the default is the
  /// default, so sliding back to it ends the place's own radius.
  void _settle(double meters) {
    final name = _adjusting?.name;
    if (name == null) return;
    final settings = widget.services.settings;
    final standard = settings.value.placeFinder.radiusMeters;
    final own = (meters - standard).abs() <= standard * 0.03 ? null : meters;
    settings.update(settings.value.withPlaceRadius(name, own));
    setState(() {
      _draft = null;
      _settled = true;
    });
  }

  /// The radius being slid, for the map to keep in view.
  ({GeoPoint at, double meters, bool settled})? get _focus {
    final group = _adjusting;
    final at = group?.marker;
    final name = group?.name;
    if (at == null || name == null) return null;
    return (at: at, meters: _radiusFor(name), settled: _settled);
  }

  void _stopSliding() => setState(() {
    _adjusting = null;
    _draft = null;
  });

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
                slider: name == null || group != _adjusting
                    ? null
                    : RadiusSlider(
                        place: name,
                        meters: _radiusFor(name),
                        format: (m) => Units.distance(settings, m),
                        onChanged: _drag,
                        onSettled: _settle,
                        onDone: _stopSliding,
                      ),
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
                  onZoom: _zoomTo,
                  onMove: _startMove,
                  streetMaps: settings.streetMaps,
                  links: widget.services.links,
                  radiusFor: _radiusFor,
                  focus: _focus,
                  zoomTo: _zoom,
                  centreTick: _centreTick,
                  hidden: _moving,
                  onCentreChanged: _moving == null
                      ? null
                      : (at) => _moveTo = at,
                ),
              ),
              if (_moving case PlaceGroup(:final name?)) ...[
                // A pin fixed over the map's middle, its tip on the spot.
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.place, size: 40),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text('Drag the map to move $name')),
                          TextButton(
                            onPressed: () => _finishMove(save: false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => _finishMove(save: true),
                            child: const Text('Move here'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
