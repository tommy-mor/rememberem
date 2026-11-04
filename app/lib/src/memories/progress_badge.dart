import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'progress_pie_painter.dart';

/// How near a person's face is to being remembered: a little pie that
/// fills with right answers toward [threshold], then turns green and
/// shiny, with a check.
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({
    super.key,
    required this.points,
    required this.threshold,
  });

  final int points;
  final int threshold;

  /// The green of a remembered face.
  static const rememberedColor = Color(0xFF1B7A3A);

  bool get remembered => RememberedCount.isRemembered(points, threshold);

  @override
  Widget build(BuildContext context) {
    final done = remembered;
    // Grows with large text, up to a point.
    final size = MediaQuery.textScalerOf(context).scale(22).clamp(22.0, 40.0);
    return Tooltip(
      message: done ? 'Name remembered' : '$points of $threshold right',
      excludeFromSemantics: true,
      child: Semantics(
        label: done
            ? 'Name remembered'
            : 'Face: $points of $threshold right answers to remember',
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: ProgressPiePainter(
              fraction: points / threshold,
              color: done
                  ? rememberedColor
                  : Theme.of(context).colorScheme.primary,
              done: done,
            ),
            child: done
                ? Icon(Icons.check, size: size * 0.64, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
