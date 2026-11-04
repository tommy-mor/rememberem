import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// A place's radius, slid in place on its row: ◀ value ▶ on a gently
/// pulsing pill. Dragging sideways moves along [RadiusScale] (the whole
/// 100 ft to 100 mi in [span] of drag); the arrows step. [onChanged] fires
/// as it moves, [onSettled] when a value is chosen. Tapping anywhere else
/// calls [onDone].
class RadiusSlider extends StatefulWidget {
  const RadiusSlider({
    super.key,
    required this.place,
    required this.meters,
    required this.format,
    required this.onChanged,
    required this.onSettled,
    required this.onDone,
  });

  final String place;
  final double meters;
  final String Function(double meters) format;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSettled;
  final VoidCallback onDone;

  /// Drag distance for the whole scale.
  static const span = 300.0;

  /// One arrow tap moves this far along the scale.
  static const step = 1 / 40;

  @override
  State<RadiusSlider> createState() => _RadiusSliderState();
}

class _RadiusSliderState extends State<RadiusSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late double _position = RadiusScale.positionOf(widget.meters);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A slow pulse says "this moves"; none for those who turn motion off.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RadiusSlider old) {
    super.didUpdateWidget(old);
    if (old.meters != widget.meters) {
      _position = RadiusScale.positionOf(widget.meters);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _moveBy(double delta, {required bool settle}) {
    final next = (_position + delta).clamp(0.0, 1.0);
    setState(() => _position = next);
    final meters = RadiusScale.metersAt(next);
    settle ? widget.onSettled(meters) : widget.onChanged(meters);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = widget.format(RadiusScale.metersAt(_position));
    return TapRegion(
      onTapOutside: (_) => widget.onDone(),
      child: Semantics(
        slider: true,
        label: 'Radius of ${widget.place}',
        value: value,
        increasedValue: widget.format(
          RadiusScale.metersAt((_position + RadiusSlider.step).clamp(0, 1)),
        ),
        decreasedValue: widget.format(
          RadiusScale.metersAt((_position - RadiusSlider.step).clamp(0, 1)),
        ),
        onIncrease: () => _moveBy(RadiusSlider.step, settle: true),
        onDecrease: () => _moveBy(-RadiusSlider.step, settle: true),
        child: GestureDetector(
          onHorizontalDragUpdate: (d) =>
              _moveBy(d.primaryDelta! / RadiusSlider.span, settle: false),
          onHorizontalDragEnd: (_) =>
              widget.onSettled(RadiusScale.metersAt(_position)),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  scheme.primaryContainer,
                  scheme.primary.withAlpha(110),
                  _pulse.value,
                ),
                border: Border.all(color: scheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: child,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Smaller',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _position <= 0
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          _moveBy(-RadiusSlider.step, settle: true);
                        },
                ),
                ExcludeSemantics(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Larger',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _position >= 1
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          _moveBy(RadiusSlider.step, settle: true);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
