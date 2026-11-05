import 'dart:io';

import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// A person's photo at the 4:5 portrait shape, at one of the sizes in
/// [RememberemTheme] (`thumbSmall`, `thumbRow`, `thumbTimeline`,
/// `thumbCard`). It decodes no larger than it shows. [label], if given,
/// names the person for a screen reader; leave it out where the name sits
/// beside the photo.
class PortraitThumb extends StatelessWidget {
  const PortraitThumb({
    super.key,
    required this.photo,
    this.size = RememberemTheme.thumbRow,
    this.label,
  });

  final File photo;
  final Size size;
  final String? label;

  double get _radius => size.width <= 24
      ? 5
      : size.width < 100
      ? 7
      : 9;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pixels = MediaQuery.devicePixelRatioOf(context);
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.person_rounded,
        size: size.width * 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: SizedBox.fromSize(
        size: size,
        child: Image(
          image: ResizeImage(
            FileImage(photo),
            width: (size.width * pixels).ceil(),
          ),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
    return label == null
        ? ExcludeSemantics(child: image)
        : Semantics(
            label: label,
            image: true,
            child: ExcludeSemantics(child: image),
          );
  }
}
