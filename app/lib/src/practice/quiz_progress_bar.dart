import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// A 3 dp bar for the foot of a quiz's app bar: how far through the turns
/// the game is, in gold. A null [value] is a bar that keeps moving, for
/// loading. The title already says "Turn N of M", so a screen reader skips
/// the bar.
class QuizProgressBar extends StatelessWidget implements PreferredSizeWidget {
  const QuizProgressBar({super.key, this.value});

  final double? value;

  @override
  Size get preferredSize => const Size.fromHeight(3);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: LinearProgressIndicator(
        value: value,
        minHeight: 3,
        color: RememberemTheme.gold,
        backgroundColor: scheme.primary.withValues(alpha: 0.18),
      ),
    );
  }
}
