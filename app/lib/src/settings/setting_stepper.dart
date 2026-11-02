import 'package:flutter/material.dart';

/// A number with minus and plus buttons, kept within [range].
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
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value <= range.min
                ? null
                : () => onChanged((value - step).clamp(range.min, range.max)),
          ),
          SizedBox(
            width: 72,
            child: Text(format(value), textAlign: TextAlign.center),
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value >= range.max
                ? null
                : () => onChanged((value + step).clamp(range.min, range.max)),
          ),
        ],
      ),
    );
  }
}
