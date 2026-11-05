import 'package:flutter/material.dart';

import '../app/rememberem_theme.dart';

/// The four corner handles of the crop frame: gold L shapes, 16 dp along
/// each side, drawn over the frame's white edge.
class CropCorners extends StatelessWidget {
  const CropCorners({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: CustomPaint(painter: _CornerPainter(), size: Size.infinite),
  );
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  static const _length = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RememberemTheme.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, _length)
      ..lineTo(0, 0)
      ..lineTo(_length, 0)
      ..moveTo(w - _length, 0)
      ..lineTo(w, 0)
      ..lineTo(w, _length)
      ..moveTo(w, h - _length)
      ..lineTo(w, h)
      ..lineTo(w - _length, h)
      ..moveTo(_length, h)
      ..lineTo(0, h)
      ..lineTo(0, h - _length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
