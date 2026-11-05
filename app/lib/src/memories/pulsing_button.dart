import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// A tonal button that pulses its gold tint three times to show what is
/// still missing, then stays tinted. It pulses again each time it is built
/// anew, as when its card is opened. It shows the full tint, still, when
/// the phone asks for less motion.
class PulsingButton extends StatefulWidget {
  const PulsingButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  /// How many times it pulses before it settles.
  static const cycles = 3;

  /// The gold tint at rest.
  static const tint = 0.35;

  @override
  State<PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<PulsingButton>
    with SingleTickerProviderStateMixin {
  /// 1 is the full tint, which it starts and ends on; a cycle is down to 0
  /// and back up.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _pulse.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _pulse.forward();
      } else if (status == AnimationStatus.completed) {
        if (++_done < PulsingButton.cycles) _pulse.reverse();
      }
    });
    _pulse.reverse();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final base = RememberemTheme.raised(theme);
    final tinted = Color.alphaBlend(
      RememberemTheme.gold.withValues(alpha: PulsingButton.tint),
      base,
    );
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => FilledButton.tonal(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: Color.lerp(base, tinted, still ? 1 : _pulse.value),
          foregroundColor: theme.colorScheme.onSurface,
        ),
        onPressed: widget.onPressed,
        child: child,
      ),
      child: Text(widget.label),
    );
  }
}
