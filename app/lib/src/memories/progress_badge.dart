import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/rememberem_theme.dart';

/// How near a person's face is to being remembered: a small outlined bar
/// that fills with right answers toward [threshold], then becomes a green
/// check.
class ProgressBadge extends StatelessWidget {
  const ProgressBadge({
    super.key,
    required this.points,
    required this.threshold,
  });

  final int points;
  final int threshold;

  static const barWidth = 48.0;
  static const barHeight = 6.0;

  bool get remembered => RememberedCount.isRemembered(points, threshold);

  @override
  Widget build(BuildContext context) {
    final done = remembered;
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: done ? 'Name remembered' : '$points of $threshold right',
      excludeFromSemantics: true,
      child: Semantics(
        label: done
            ? 'Name remembered'
            : 'Face: $points of $threshold right answers to remember',
        child: done
            ? const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: RememberemTheme.rememberedGreen,
              )
            : Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: primary),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(
                    color: primary.withValues(alpha: 0.16),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: (points / threshold).clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(color: primary),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
