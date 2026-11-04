import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// A labelled row of colour swatches; the chosen one is ticked.
class ColourChoice extends StatelessWidget {
  const ColourChoice({
    super.key,
    required this.label,
    required this.colours,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;

  /// ARGB values, from [AppPalette].
  final List<int> colours;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return ListTile(
      enabled: enabled,
      title: Text(label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          children: [
            for (final colour in colours)
              _swatch(
                Color(colour),
                AppPalette.names[colour] ?? '',
                outline,
                colour == value,
                colour,
              ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(
    Color colour,
    String name,
    Color outline,
    bool chosen,
    int value,
  ) {
    final tick = ThemeData.estimateBrightnessForColor(colour) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: chosen,
        label: name,
        child: InkResponse(
          onTap: enabled ? () => onChanged(value) : null,
          radius: 24,
          // 48 dp to tap, 36 dp to see.
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                  border: Border.all(color: outline, width: chosen ? 3 : 1),
                ),
                child: chosen ? Icon(Icons.check, size: 20, color: tick) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
