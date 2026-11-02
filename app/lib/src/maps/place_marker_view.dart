import 'package:flutter/material.dart';

/// What a [PlaceMarker] looks like: a name tag above a pin.
class PlaceMarkerView extends StatelessWidget {
  const PlaceMarkerView(
    this.label, {
    super.key,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
