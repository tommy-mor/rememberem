import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// What a list says when it has nothing: a line, some help under it, and
/// at most one button. Flush left at the gutter, a little below the bar.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.help,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? help;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          RememberemTheme.gutter,
          32,
          RememberemTheme.gutter,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (help != null) ...[
              const SizedBox(height: 8),
              Text(help!, style: theme.textTheme.bodyMedium),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
