import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// A list row that is picked: a 3 dp bar of the theme colour down its
/// leading edge, a 6 % tint, a check icon at the end, and
/// `Semantics(selected: true)`. Never colour alone. Not picked, it is just
/// [child]. A row of one control reads as one stop; a [mergeSemantics]
/// false row holds several controls (a name box, buttons), which stay
/// separate stops under one selected node.
class SelectedRow extends StatelessWidget {
  const SelectedRow({
    super.key,
    required this.selected,
    required this.child,
    this.mergeSemantics = true,
  });

  final bool selected;
  final Widget child;
  final bool mergeSemantics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Semantics(
      selected: selected,
      container: !mergeSemantics && selected,
      child: Stack(
        children: [
          child,
          if (selected) ...[
            // Over the row, not behind it: a ListTile paints on the
            // Material above it, which a coloured box would hide.
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: scheme.primary),
            ),
            PositionedDirectional(
              end: RememberemTheme.gutter,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return mergeSemantics ? MergeSemantics(child: row) : row;
  }
}
