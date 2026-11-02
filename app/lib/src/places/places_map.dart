import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'place_map_painter.dart';
import 'place_map_projection.dart';

/// A street-less map of where places are, drawn on the phone: nothing is
/// fetched from a map service, so where Fred has been never leaves it.
class PlacesMap extends StatelessWidget {
  const PlacesMap({
    super.key,
    required this.groups,
    required this.selected,
    required this.onSelect,
  });

  final List<PlaceGroup> groups;
  final PlaceGroup? selected;
  final ValueChanged<PlaceGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    final located = [
      for (final g in groups)
        if (g.marker != null) g,
    ];
    final points = [for (final g in located) g.marker!];
    final selectedIndex = selected == null ? null : located.indexOf(selected!);
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return const Center(child: Text('No places with a location yet.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final projection = PlaceMapProjection(
          points,
          constraints.biggest,
          centre: selectedIndex == null || selectedIndex < 0
              ? null
              : points[selectedIndex],
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final hit = projection.hitTest(details.localPosition, points);
            if (hit != null) onSelect(located[hit]);
          },
          child: CustomPaint(
            size: constraints.biggest,
            painter: PlaceMapPainter(
              projection: projection,
              points: points,
              labels: [for (final g in located) g.label],
              selected: selectedIndex == null || selectedIndex < 0
                  ? null
                  : selectedIndex,
              color: theme.colorScheme.primary,
              textStyle: theme.textTheme.bodySmall!,
            ),
          ),
        );
      },
    );
  }
}
