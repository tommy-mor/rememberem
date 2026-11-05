import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// A box drawn over one face in a photo, [faceSize] in the middle of a
/// larger tap target; tapping it chooses or unchooses that face. A chosen
/// face is filled and carries a check, so it is not told by colour alone.
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

  static final _radius = BorderRadius.circular(6);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: SizedBox.fromSize(size: faceSize, child: _box()),
          ),
        ),
      ),
    );
  }

  Widget _box() => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: _radius,
      border: Border.all(color: RememberemTheme.gold, width: 2),
      color: chosen ? RememberemTheme.gold.withValues(alpha: 0.25) : null,
      // A dark edge keeps the gold box visible on a pale background.
      boxShadow: const [BoxShadow(color: Colors.black54, spreadRadius: 1)],
    ),
    child: chosen
        ? const Align(
            alignment: Alignment.topRight,
            child: Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: RememberemTheme.gold,
            ),
          )
        : const SizedBox.expand(),
  );
}
