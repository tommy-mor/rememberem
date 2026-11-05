import 'dart:async';

import 'package:flutter/material.dart';

/// A button with a thin gold bar along its foot that drains from full to
/// empty over [duration], and presses itself when it is gone. A tap
/// presses it at once. While [running] is false (the app is hidden) it stands full and
/// waits; when it runs again it starts from full. It presses once only.
class CountdownButton extends StatefulWidget {
  const CountdownButton({
    super.key,
    required this.label,
    required this.duration,
    required this.running,
    required this.onPressed,
  });

  final String label;
  final Duration duration;
  final bool running;
  final VoidCallback onPressed;

  @override
  State<CountdownButton> createState() => _CountdownButtonState();
}

class _CountdownButtonState extends State<CountdownButton>
    with SingleTickerProviderStateMixin {
  /// Only draws the bar draining; [_timer] presses, so the press comes exactly
  /// [CountdownButton.duration] after the countdown starts.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;
  bool _pressed = false;

  /// Leaving the app stops the countdown at once, before any rebuild;
  /// coming back starts it again from empty.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onInactive: _stop,
    onResume: () {
      if (widget.running) _start();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // created now, so it listens from the start
    if (widget.running) _start();
  }

  void _stop() {
    _timer?.cancel();
    _fill.reset();
  }

  void _start() {
    if (_pressed) return;
    _timer?.cancel();
    _timer = Timer(widget.duration, _press);
    _fill.forward(from: 0);
  }

  @override
  void didUpdateWidget(CountdownButton old) {
    super.didUpdateWidget(old);
    _fill.duration = widget.duration;
    if (widget.running == old.running) return;
    if (widget.running) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    _fill.dispose();
    super.dispose();
  }

  void _press() {
    if (_pressed || !mounted) return;
    _pressed = true;
    _timer?.cancel();
    _fill.stop();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return Semantics(
      button: true,
      hint: widget.running
          ? 'Shows by itself after ${widget.duration.inSeconds} seconds'
          : null,
      child: Material(
        color: scheme.secondaryContainer,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _press,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _fill,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1 - _fill.value,
                    // Primary, not gold: gold is 1.6:1 on the pale button.
                    child: SizedBox(
                      height: 4,
                      child: ColoredBox(color: scheme.primary),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
