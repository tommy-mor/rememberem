import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// A small, encouraging line: how many faces and details Fred remembers.
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
    return Text(
      count.isNothing
          ? 'Remembered: nothing yet, practice to start'
          : 'Remembered: $faces · $details',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
