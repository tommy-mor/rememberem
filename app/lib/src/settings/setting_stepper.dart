import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// A number with minus and plus buttons in one outlined pill, kept within
/// [range]. The label is on the left; on a narrow screen the pill drops
/// beneath it.
class SettingStepper extends StatelessWidget {
  const SettingStepper({
    super.key,
    required this.label,
    required this.value,
    required this.range,
    required this.onChanged,
    this.step = 1,
    this.format = _plain,
  });

  final String label;
  final int value;
  final ({int min, int max}) range;
  final int step;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  static String _plain(int v) => '$v';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RememberemTheme.gutter,
        vertical: 2,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Align(
                widthFactor: 1,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: RememberemTheme.tapTarget,
                    height: RememberemTheme.tapTarget,
                  ),
                  tooltip: 'Less',
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: value <= range.min
                      ? null
                      : () => onChanged(
                          (value - step).clamp(range.min, range.max),
                        ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 64),
                  child: Text(
                    format(value),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: RememberemTheme.tapTarget,
                    height: RememberemTheme.tapTarget,
                  ),
                  tooltip: 'More',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: value >= range.max
                      ? null
                      : () => onChanged(
                          (value + step).clamp(range.min, range.max),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
