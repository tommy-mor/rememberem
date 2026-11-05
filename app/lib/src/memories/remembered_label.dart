import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// A small, encouraging two lines: how many faces and details Fred remembers.
class RememberedLabel extends StatelessWidget {
  const RememberedLabel(this.count, {super.key});

  final RememberedCount count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faces = count.faces == 1 ? '1 face' : '${count.faces} faces';
    final details = count.details == 1
        ? '1 detail'
        : '${count.details} details';
    final summary = count.isNothing
        ? 'nothing yet, practice to start'
        : '$faces · $details';
    return Semantics(
      label: 'Remembered: $summary',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remembered',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            summary,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
