import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../maps/place_marker.dart';
import '../maps/street_map.dart';

/// Where places are, on a street map (or a plain one, per Settings). The
/// selected place is centred and highlighted; its people are in the list.
class PlacesMap extends StatelessWidget {
  const PlacesMap({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.streetMaps,
  });

  final List<PlaceGroup> groups;
  final PlaceGroup? selected;
  final ValueChanged<PlaceGroup> onSelect;
  final bool streetMaps;

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
    return StreetMap(
      streetMaps: streetMaps,
      centre: selected?.marker,
      fitAll: [for (final g in located) g.marker!],
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
