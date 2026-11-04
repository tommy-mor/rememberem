import 'dart:math';

import 'package:flutter/material.dart';

/// A small pie: a faint full circle with [fraction] of it filled from the
/// top, clockwise. When [done], a solid circle with a white shine.
class ProgressPiePainter extends CustomPainter {
  const ProgressPiePainter({
    required this.fraction,
    required this.color,
    required this.done,
  });

  final double fraction;
  final Color color;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    if (done) {
      canvas.drawCircle(center, radius, Paint()..color = color);
      // A shine near the top left.
      final shine = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.6, -0.65),
          radius: 0.45,
          colors: [Colors.white.withAlpha(90), Colors.white.withAlpha(0)],
        ).createShader(rect);
      canvas.drawCircle(center, radius, shine);
      return;
    }
    canvas.drawCircle(center, radius, Paint()..color = color.withAlpha(60));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * fraction.clamp(0.0, 1.0),
      true,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(ProgressPiePainter old) =>
      old.fraction != fraction || old.color != color || old.done != done;
}
