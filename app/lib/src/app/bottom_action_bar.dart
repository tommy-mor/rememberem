import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// A bar along the foot of a page, at least 46 dp tall, with a rule above
/// it: [start] on the left, [middle] filling the space between, and [end]
/// on the right, where the page's one primary action goes in
/// [goldStyle]. It clears the phone's navigation bar and any cutout at its
/// sides, and sits on the keyboard when that is up.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    this.start,
    this.middle,
    this.end,
    this.color,
  });

  final Widget? start;
  final Widget? middle;
  final Widget? end;

  /// The fill, where the page is not pale gold: black over a camera.
  final Color? color;

  /// The primary action's look: deep navy on gold, 46 dp tall.
  static final goldStyle = FilledButton.styleFrom(
    backgroundColor: RememberemTheme.gold,
    foregroundColor: RememberemTheme.deepNavy,
    minimumSize: const Size(0, 46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );

  /// The bar's fill: pale gold, or a raised surface in the dark theme.
  static Color surfaceOf(ThemeData theme) => theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHigh
      : RememberemTheme.paleGold;

  Widget _side(Widget side) => middle == null ? Flexible(child: side) : side;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    // Clear of the navigation bar, or of the keyboard when that is up
    // (which covers it): a Scaffold leaves a bottom bar under the keyboard
    // unless it lifts itself.
    final bottom = math.max(media.viewPadding.bottom, media.viewInsets.bottom);
    return Material(
      color: color ?? surfaceOf(theme),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: RememberemTheme.rule(theme))),
        ),
        child: Padding(
          // Clear of a notch or a rail beside the page, as of the foot.
          padding: EdgeInsets.fromLTRB(
            RememberemTheme.gutter + media.viewPadding.left,
            0,
            RememberemTheme.gutter + media.viewPadding.right,
            bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            // With no middle, each side may shrink so large text wraps
            // rather than overflows, and a lone action sits at its own
            // end. A middle takes what the sides leave.
            child: Row(
              mainAxisAlignment: start == null
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (start != null) _side(start!),
                if (middle != null) Expanded(child: middle!),
                if (end != null) _side(end!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
