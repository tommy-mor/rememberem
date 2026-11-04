import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/link_opener.dart';
import '../maps/place_circle.dart';
import '../maps/place_marker.dart';
import '../maps/street_map.dart';

/// Where places are, on a street map (or a plain one, per Settings), each
/// named place with its radius. The selected place is centred,
/// highlighted and drawn on top; its people are in the list. A double
/// tap on a place zooms to it; a long press on a named one moves it.
class PlacesMap extends StatelessWidget {
  const PlacesMap({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.streetMaps,
    required this.links,
    required this.radiusFor,
    required this.onZoom,
    required this.onMove,
    this.focus,
    this.zoomTo,
    this.centreTick = 0,
    this.hidden,
    this.onCentreChanged,
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

  /// See [StreetMap.centreTick].
  final int centreTick;

  /// See [StreetMap.zoomTo].
  final ({GeoPoint at, double meters, int tick})? zoomTo;

  final ValueChanged<PlaceGroup> onZoom;

  /// Starts moving a named place.
  final ValueChanged<PlaceGroup> onMove;

  /// A place being moved, drawn by the screen instead.
  final PlaceGroup? hidden;

  final ValueChanged<GeoPoint>? onCentreChanged;

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
    // The selected place last, so it is drawn on top.
    final ordered = [
      for (final g in located)
        if (g != selected && g != hidden) g,
      if (selected != null && selected != hidden && located.contains(selected))
        selected,
    ];
    return StreetMap(
      streetMaps: streetMaps,
      links: links,
      centre: selected?.marker,
      fitAll: [for (final g in located) g.marker!],
      focus: focus,
      centreTick: centreTick,
      zoomTo: zoomTo,
      onCentreChanged: onCentreChanged,
      circles: [
        for (final g in ordered)
          if (g.name case final name?)
            PlaceCircle(
              at: g.marker!,
              meters: radiusFor(name),
              scheme: scheme,
              selected: g == selected,
            ),
      ],
      markers: [
        for (final g in ordered)
          PlaceMarker(
            at: g.marker!,
            label: g.label,
            selected: g == selected,
            onTap: () => onSelect(g),
            onDoubleTap: () => onZoom(g),
            onLongPress: g.name == null ? null : () => onMove(g),
          ),
      ],
    );
  }
}
