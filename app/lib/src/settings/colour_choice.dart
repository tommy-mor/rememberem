import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/rememberem_theme.dart';

/// A labelled, wrapping group of colour swatches; the chosen one has a ring
/// and a tick.
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RememberemTheme.gutter,
        vertical: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.disabledColor,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final colour in colours)
                _swatch(
                  theme,
                  Color(colour),
                  AppPalette.names[colour] ?? '',
                  colour == value,
                  colour,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(
    ThemeData theme,
    Color colour,
    String name,
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
        enabled: enabled,
        label: name,
        // The tap is given again here: excluding the child's semantics
        // would otherwise drop it.
        onTap: enabled ? () => onChanged(value) : null,
        excludeSemantics: true,
        child: InkResponse(
          onTap: enabled ? () => onChanged(value) : null,
          radius: 24,
          // 48 dp to tap, 32 dp to see.
          child: SizedBox(
            width: RememberemTheme.tapTarget,
            height: RememberemTheme.tapTarget,
            child: Center(
              child: Opacity(
                opacity: enabled ? 1 : 0.4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: chosen
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                      width: chosen ? 2 : 1,
                    ),
                  ),
                  child: chosen
                      ? Icon(Icons.check_rounded, size: 20, color: tick)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
