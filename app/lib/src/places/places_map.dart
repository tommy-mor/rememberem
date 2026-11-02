import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../maps/place_marker.dart';
import '../maps/street_map.dart';
import '../memories/person_chip.dart';

/// Where places are, on a street map (or a plain one, per Settings). The
/// selected place's people show over the map; tapping one opens them.
class PlacesMap extends StatelessWidget {
  const PlacesMap({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.onOpenPerson,
    required this.repository,
    required this.streetMaps,
  });

  final List<PlaceGroup> groups;
  final PlaceGroup? selected;
  final ValueChanged<PlaceGroup> onSelect;
  final ValueChanged<Memory> onOpenPerson;
  final MemoryRepository repository;
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
    return Stack(
      children: [
        StreetMap(
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
        ),
        if (selected != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final person in selected.people)
                      PersonChip(
                        memory: person,
                        repository: repository,
                        onTap: () => onOpenPerson(person),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
