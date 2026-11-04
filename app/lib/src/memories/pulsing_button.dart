import 'package:flutter/material.dart';

/// A tonal button whose background gently pulses, to show what is still
/// missing. It holds still when the phone asks for less motion.
class PulsingButton extends StatefulWidget {
  const PulsingButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<PulsingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => FilledButton.tonal(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: Color.lerp(
            scheme.secondaryContainer,
            scheme.primaryContainer,
            _pulse.value,
          ),
          foregroundColor: scheme.onPrimaryContainer,
        ),
        onPressed: widget.onPressed,
        child: child,
      ),
      child: Text(widget.label),
    );
  }
}
