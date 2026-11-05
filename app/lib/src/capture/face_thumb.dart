import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/rememberem_theme.dart';

/// One face cut out of a photo that is not saved yet, at the size of a
/// list row's portrait ([PortraitThumb] reads a saved file; this reads the
/// photo's bytes). [label] names it for a screen reader.
class FaceThumb extends StatelessWidget {
  const FaceThumb({
    super.key,
    required this.photo,
    required this.face,
    required this.label,
    this.size = RememberemTheme.thumbRow,
  });

  final UprightPhoto photo;
  final PixelRect face;
  final String label;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: SizedBox.fromSize(
            size: size,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: face.width.toDouble(),
                height: face.height.toDouble(),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: photo.width.toDouble(),
                    maxWidth: photo.width.toDouble(),
                    minHeight: photo.height.toDouble(),
                    maxHeight: photo.height.toDouble(),
                    child: Transform.translate(
                      offset: Offset(
                        -face.left.toDouble(),
                        -face.top.toDouble(),
                      ),
                      child: Image.memory(
                        photo.jpeg,
                        width: photo.width.toDouble(),
                        height: photo.height.toDouble(),
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
