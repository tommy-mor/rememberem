import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/home_button.dart';
import 'location_choice.dart';
import 'place_circle.dart';
import 'place_marker.dart';
import 'place_name_dialog.dart';
import 'street_map.dart';

/// Pick a spot by moving the map under the crosshair, or tap a known place's
/// pin to choose that place. Above the map, the known places by name: one
/// tapped is centred on the map. Pops with a [LocationChoice] naming the known
/// place at the spot (if any), or nothing if Fred goes back.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.services,
    required this.initial,
    this.initialPlace,
    this.askName = false,
  });

  final AppServices services;

  /// The current location, if there is one.
  final GeoPoint? initial;

  /// The current place's name: with no [initial] location, the map starts
  /// at that known place.
  final String? initialPlace;

  /// Ask Fred to name a spot that is not a known place (a happening's
  /// place), instead of leaving it blank.
  final bool askName;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  List<PlaceGroup> _places = const [];

  /// Everyone, for finding the known place at a spot.
  List<Memory> _people = const [];
  GeoPoint? _start;
  bool _loading = true;

  /// Where the crosshair is now.
  GeoPoint? _centre;

  /// The place last tapped in the list, and a count of taps, so tapping
  /// it again looks at it again.
  String? _picked;
  int _pickTick = 0;

  /// The known places in alphabetical order.
  List<PlaceGroup> get _byName => [..._places]
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Known places to mark, and where to start: the picture's location,
  /// else here, else the newest known place, else the whole world.
  Future<void> _load() async {
    var places = const <PlaceGroup>[];
    var people = const <Memory>[];
    try {
      people = await widget.services.repository.all();
      places = [
        for (final g in PlaceBook.from(
          people,
          spots: widget.services.settings.value.placeSpots,
        ).groups)
          if (g.name != null && g.marker != null) g,
      ];
    } catch (_) {
      // Marks are only a help.
    }
    final named = DetailTypeCatalog.normalizeKey(widget.initialPlace ?? '');
    var start =
        widget.initial ??
        places
            .where((g) => DetailTypeCatalog.normalizeKey(g.label) == named)
            .firstOrNull
            ?.marker;
    if (start == null) {
      try {
        start = await widget.services.location.current();
      } catch (_) {
        // No fix: fall through.
      }
    }
    start ??= places.firstOrNull?.marker;
    if (!mounted) return;
    setState(() {
      _places = places;
      _people = people;
      _start = start;
      _centre = start;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Where was this?'),
        actions: const [HomeButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_places.isNotEmpty) _placeList(context),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      StreetMap(
                        streetMaps: widget.services.settings.value.streetMaps,
                        links: widget.services.links,
                        centre: _start,
                        centreTick: _pickTick,
                        circles: [
                          for (final g in _places)
                            if (g.name case final name?)
                              PlaceCircle(
                                at: g.marker!,
                                meters: widget.services.settings.value
                                    .radiusFor(name),
                                scheme: Theme.of(context).colorScheme,
                              ),
                        ],
                        markers: [
                          for (final g in _places)
                            PlaceMarker(
                              at: g.marker!,
                              label: g.label,
                              onTap: () => Navigator.of(context).pop(
                                LocationChoice.at(g.marker!, place: g.label),
                              ),
                            ),
                        ],
                        onCentreChanged: _moved,
                      ),
                      IgnorePointer(
                        child: Icon(
                          Icons.add,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                _buttons(context),
              ],
            ),
    );
  }

  /// The map moved: once it leaves the place picked in the list, that
  /// place is no longer marked as picked.
  void _moved(GeoPoint centre) {
    _centre = centre;
    final at = _start;
    if (_picked == null || at == null) return;
    const near = 1e-6;
    if ((centre.latitude - at.latitude).abs() > near ||
        (centre.longitude - at.longitude).abs() > near) {
      setState(() => _picked = null);
    }
  }

  /// The known places, a few lines high; tapping one centres it.
  Widget _placeList(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      // A few lines, but never most of a short (landscape) screen.
      height: min(168, MediaQuery.sizeOf(context).height * 0.25),
      child: Scrollbar(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (final g in _byName)
              ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -4),
                leading: const Icon(Icons.place, size: 20),
                title: Text(g.label),
                selected: g.label == _picked,
                trailing: g.label == _picked
                    ? const Icon(Icons.check, semanticLabel: 'Chosen')
                    : null,
                selectedTileColor: theme.colorScheme.primaryContainer.withAlpha(
                  90,
                ),
                onTap: () => setState(() {
                  _picked = g.label;
                  _start = g.marker;
                  _centre = g.marker;
                  _pickTick++;
                }),
              ),
          ],
        ),
      ),
    );
  }

  /// The crosshair's spot, named after the known place there, if any.
  Future<void> _useCentre() async {
    final centre = _centre;
    if (centre == null) return;
    final settings = widget.services.settings.value;
    var place = settings.placeFinder.nearest(centre, _people)?.place ?? '';
    if (widget.askName) {
      final named = await showDialog<String>(
        context: context,
        builder: (_) => PlaceNameDialog(initial: place),
      );
      if (named == null || !mounted) return;
      place = named;
    }
    if (!mounted) return;
    Navigator.of(context).pop(LocationChoice.at(centre, place: place));
  }

  Widget _buttons(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
                onPressed: () =>
                    Navigator.of(context).pop(const LocationChoice.remote()),
                icon: const Icon(Icons.wifi),
                label: const Text('Remote'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                // With nowhere to start, wait for Fred to move the map.
                onPressed: _useCentre,
                icon: const Icon(Icons.check),
                label: const Text('Use this spot'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
