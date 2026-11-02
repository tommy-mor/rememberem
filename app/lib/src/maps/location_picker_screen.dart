import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import 'location_choice.dart';
import 'place_marker.dart';
import 'street_map.dart';

/// Pick where a picture was taken by moving the map under the crosshair.
/// Known places are marked to make the map easy to read. Pops with a
/// [LocationChoice], or nothing if Fred goes back.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.services,
    required this.initial,
  });

  final AppServices services;

  /// The picture's current location, if it has one.
  final GeoPoint? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  List<PlaceGroup> _places = const [];
  GeoPoint? _start;
  bool _loading = true;

  /// Where the crosshair is now.
  GeoPoint? _centre;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Known places to mark, and where to start: the picture's location,
  /// else here, else the newest known place, else the whole world.
  Future<void> _load() async {
    var places = const <PlaceGroup>[];
    try {
      final groups = PlaceBook.from(await widget.services.repository.all());
      places = [
        for (final g in groups.groups)
          if (g.name != null && g.marker != null) g,
      ];
    } catch (_) {
      // Marks are only a help.
    }
    var start = widget.initial;
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
      _start = start;
      _centre = start;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Where was this?')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      StreetMap(
                        streetMaps: widget.services.settings.value.streetMaps,
                        centre: _start,
                        markers: [
                          for (final g in _places)
                            PlaceMarker(at: g.marker!, label: g.label),
                        ],
                        onCentreChanged: (c) => _centre = c,
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
                onPressed: () {
                  final centre = _centre;
                  if (centre != null) {
                    Navigator.of(context).pop(LocationChoice.at(centre));
                  }
                },
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
