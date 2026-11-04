import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// What a [PlaceMarker] looks like: a name tag above a pin. A double tap
/// and a long press, where given, are also screen-reader actions.
class PlaceMarkerView extends StatelessWidget {
  const PlaceMarkerView(
    this.label, {
    super.key,
    required this.selected,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Zooms to the place.
  final VoidCallback? onDoubleTap;

  /// Starts moving the place.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Zoom to this place'): ?onDoubleTap,
        const CustomSemanticsAction(label: 'Move this place'): ?onLongPress,
      },
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Flexible: large text shrinks the tag rather than overflowing.
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(blurRadius: 2, color: Colors.black26),
                  ],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
            Icon(
              Icons.place,
              size: 32,
              color: selected ? scheme.secondary : scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
