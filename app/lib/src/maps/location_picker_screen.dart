import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/bottom_action_bar.dart';
import '../app/home_button.dart';
import '../app/rememberem_theme.dart';
import 'location_choice.dart';
import 'place_circle.dart';
import 'place_marker.dart';
import 'place_name_dialog.dart';
import 'street_map.dart';

/// Pick a spot by moving the map under the crosshair, or tap a known place's
/// pin to choose that place. Above the map, the known places by name, each
/// with a radio: one tapped is centred on the map. Under the map, a strip
/// names the place the crosshair would choose. Pops with a [LocationChoice]
/// naming the known place at the spot (if any), or nothing if Fred goes
/// back.
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

  /// The known place at the crosshair (blank if none), for the strip.
  String _near = '';

  /// The known places in alphabetical order.
  List<PlaceGroup> get _byName => [..._places]
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The known place nearest [at], by the settings' radius, or blank.
  String _placeAt(GeoPoint at, List<Memory> people) =>
      widget.services.settings.value.placeFinder.nearest(at, people)?.place ??
      '';

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
      _near = start == null ? '' : _placeAt(start, people);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Where was this?'),
        actions: const [HomeButton()],
      ),
      body: _loading
          ? const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                minHeight: 3,
                semanticsLabel: 'Loading',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_places.isNotEmpty) _placeList(context),
                Expanded(
                  child: DecoratedBox(
                    // A 2 dp rule of the theme colour along the map's
                    // bottom edge, as on Places.
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: scheme.primary, width: 2),
                      ),
                    ),
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
                                  scheme: scheme,
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
                          child: Icon(Icons.add, size: 48, color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
                _chosenStrip(context),
                _buttons(context),
              ],
            ),
    );
  }

  /// The map moved: once it leaves the place picked in the list, that
  /// place is no longer marked as picked, and the strip names whatever
  /// known place is under the crosshair now.
  void _moved(GeoPoint centre) {
    _centre = centre;
    final at = _start;
    const near = 1e-6;
    final left =
        _picked != null &&
        at != null &&
        ((centre.latitude - at.latitude).abs() > near ||
            (centre.longitude - at.longitude).abs() > near);
    final place = _placeAt(centre, _people);
    if (!left && place == _near) return;
    void apply() {
      if (!mounted) return;
      setState(() {
        if (left) _picked = null;
        _near = place;
      });
    }

    // The map reports a move it was told to make while it is being built.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// The place the crosshair would choose: the one picked in the list,
  /// else the known place at the crosshair. Under the map, not over it,
  /// because the map's attribution must stay in view. Absent when the spot
  /// is no known place.
  Widget _chosenStrip(BuildContext context) {
    final place = _picked ?? _near;
    if (place.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: BottomActionBar.surfaceOf(theme),
      child: Semantics(
        liveRegion: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding:
                EdgeInsets.symmetric(
                  horizontal: RememberemTheme.gutter,
                  vertical: 8,
                ).add(
                  EdgeInsets.only(
                    left: MediaQuery.viewPaddingOf(context).left,
                    right: MediaQuery.viewPaddingOf(context).right,
                  ),
                ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.place_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: RememberemTheme.thumbGap),
                Expanded(
                  child: Text(
                    place,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The known places, a few lines high; tapping one centres it.
  Widget _placeList(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      // A few lines, but never most of a short (landscape) screen.
      height: min(168, MediaQuery.sizeOf(context).height * 0.25),
      child: Scrollbar(
        child: ListView(
          children: [
            for (final g in _byName)
              ListTile(
                minTileHeight: RememberemTheme.tapTarget,
                // A radio, as these are alternatives; the filled one is
                // the pick (its label says so too).
                leading: Icon(
                  g.label == _picked
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  semanticLabel: g.label == _picked ? 'Chosen' : null,
                ),
                title: Text(g.label),
                selected: g.label == _picked,
                selectedTileColor: theme.colorScheme.primary.withValues(
                  alpha: 0.06,
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
    var place = _placeAt(centre, _people);
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
    return BottomActionBar(
      // Two equal buttons, so large text wraps in them, not off the edge.
      middle: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pop(const LocationChoice.remote()),
              child: const Text('Remote'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: BottomActionBar.goldStyle,
              // With nowhere to start, wait for Fred to move the map.
              onPressed: _useCentre,
              child: const Text('Use this spot'),
            ),
          ),
        ],
      ),
    );
  }
}
