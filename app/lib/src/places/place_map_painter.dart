import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'place_map_projection.dart';

/// Draws each place as a labelled dot; the selected one larger, ringed.
class PlaceMapPainter extends CustomPainter {
  PlaceMapPainter({
    required this.projection,
    required this.points,
    required this.labels,
    required this.selected,
    required this.color,
    required this.textStyle,
  });

  final PlaceMapProjection projection;
  final List<GeoPoint> points;
  final List<String> labels;
  final int? selected;
  final Color color;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (i, point) in points.indexed) {
      final at = projection.project(point);
      final isSelected = i == selected;
      canvas.drawCircle(at, isSelected ? 8 : 5, dot);
      if (isSelected) canvas.drawCircle(at, 13, ring);
      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: isSelected
              ? textStyle.copyWith(fontWeight: FontWeight.bold)
              : textStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 140);
      label.paint(canvas, at + const Offset(10, -8));
    }
  }

  @override
  bool shouldRepaint(PlaceMapPainter old) =>
      old.points != points || old.labels != labels || old.selected != selected;
}
