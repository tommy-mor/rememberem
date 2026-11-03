import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/link_opener.dart';
import '../maps/place_circle.dart';
import '../maps/place_marker.dart';
import '../maps/street_map.dart';

/// Where places are, on a street map (or a plain one, per Settings), each
/// named place with its radius. The selected place is centred and
/// highlighted; its people are in the list.
class PlacesMap extends StatelessWidget {
  const PlacesMap({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.streetMaps,
    required this.links,
    required this.radiusFor,
    this.focus,
  });

  final List<PlaceGroup> groups;
  final PlaceGroup? selected;
  final ValueChanged<PlaceGroup> onSelect;
  final bool streetMaps;
  final LinkOpener links;

  /// A named place's radius in metres (live while it is being adjusted).
  final double Function(String place) radiusFor;

  /// The radius being adjusted; see [StreetMap.focus].
  final ({GeoPoint at, double meters, bool settled})? focus;

  @override
  Widget build(BuildContext context) {
    final located = [
      for (final g in groups)
        if (g.marker != null) g,
    ];
    if (located.isEmpty) {
      return const Center(child: Text('No places with a location yet.'));
    }
    final selected = this.selected;
    final scheme = Theme.of(context).colorScheme;
    return StreetMap(
      streetMaps: streetMaps,
      links: links,
      centre: selected?.marker,
      fitAll: [for (final g in located) g.marker!],
      focus: focus,
      circles: [
        for (final g in located)
          if (g.name case final name?)
            PlaceCircle(
              at: g.marker!,
              meters: radiusFor(name),
              scheme: scheme,
              selected: g == selected,
            ),
      ],
      markers: [
        for (final g in located)
          PlaceMarker(
            at: g.marker!,
            label: g.label,
            selected: g == selected,
            onTap: () => onSelect(g),
          ),
      ],
    );
  }
}
