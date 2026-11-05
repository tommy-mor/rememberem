import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// How an answer stands in the faces quiz.
enum AnswerState { open, wrong, right }

/// One name to choose from, at least 54 dp tall; the whole row is the
/// tap target. A [AnswerState.right] row turns green with a check (never
/// by colour alone: it is also `selected` for a screen reader). A
/// [AnswerState.wrong] row is dimmed and, with a null [onTap], disabled;
/// it is never red, and a screen reader says "not this one".
class AnswerRow extends StatelessWidget {
  const AnswerRow({
    super.key,
    required this.name,
    required this.state,
    required this.onTap,
  });

  final String name;
  final AnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final right = state == AnswerState.right;
    final wrong = state == AnswerState.wrong;
    final color = right
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null || right,
      selected: right,
      label: right
          ? '$name, right'
          : wrong
          ? '$name, not this one'
          : name,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: wrong ? 0.35 : 1,
        child: Material(
          color: right ? RememberemTheme.rememberedGreen : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RememberemTheme.gutter,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    if (right) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded, color: color),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
