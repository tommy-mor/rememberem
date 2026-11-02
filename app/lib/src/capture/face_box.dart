import 'package:flutter/material.dart';

/// A box drawn over one face in a photo, [faceSize] in the middle of a
/// larger tap target; tapping it chooses or unchooses that face.
class FaceBox extends StatelessWidget {
  const FaceBox({
    super.key,
    required this.label,
    required this.chosen,
    required this.faceSize,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final Size faceSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = chosen
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    return Semantics(
      button: true,
      selected: chosen,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: SizedBox.fromSize(size: faceSize, child: _box(colour)),
          ),
        ),
      ),
    );
  }

  Widget _box(Color colour) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: colour, width: chosen ? 4 : 2),
      color: chosen ? colour.withValues(alpha: 0.2) : null,
      // A dark edge keeps the white box visible on a pale background.
      boxShadow: const [BoxShadow(color: Colors.black87, spreadRadius: 1)],
    ),
    child: chosen
        ? Align(
            alignment: Alignment.topRight,
            child: Icon(Icons.check_circle, color: colour),
          )
        : const SizedBox.expand(),
  );
}
