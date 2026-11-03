import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Adjusts one place's radius: a logarithmic slider from 100 feet to 100
/// miles ([RadiusScale]), with steps for those who would rather not drag.
/// [onChanged] fires as it moves; [onSettled] when a value is chosen.
class RadiusPanel extends StatelessWidget {
  const RadiusPanel({
    super.key,
    required this.place,
    required this.meters,
    required this.format,
    required this.onChanged,
    required this.onSettled,
    required this.onUseDefault,
    required this.onDone,
  });

  final String place;
  final double meters;
  final String Function(double meters) format;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSettled;
  final VoidCallback onUseDefault;
  final VoidCallback onDone;

  /// One tap of − or + moves this far along the slider.
  static const step = 1 / 40;

  void _step(int direction) => onSettled(
    RadiusScale.metersAt(RadiusScale.positionOf(meters) + direction * step),
  );

  @override
  Widget build(BuildContext context) {
    final position = RadiusScale.positionOf(meters);
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Radius of $place: ${format(meters)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Smaller',
                  icon: const Icon(Icons.remove),
                  onPressed: position <= 0 ? null : () => _step(-1),
                ),
                Expanded(
                  child: Slider(
                    value: position,
                    semanticFormatterCallback: (t) =>
                        format(RadiusScale.metersAt(t)),
                    onChanged: (t) => onChanged(RadiusScale.metersAt(t)),
                    onChangeEnd: (t) => onSettled(RadiusScale.metersAt(t)),
                  ),
                ),
                IconButton(
                  tooltip: 'Larger',
                  icon: const Icon(Icons.add),
                  onPressed: position >= 1 ? null : () => _step(1),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onUseDefault,
                  child: const Text('Use default'),
                ),
                TextButton(onPressed: onDone, child: const Text('Done')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
