import 'dart:math';
import 'dart:ui';

import 'package:rememberem_core/rememberem_core.dart';

/// Places [points] on a [size] canvas with a flat (equirectangular)
/// projection: east-west distances shrink with latitude, wrap-around at
/// the antimeridian is handled, and every point stays visible. With a
/// [centre] the map is centred on it; otherwise on the points' middle.
class PlaceMapProjection {
  PlaceMapProjection(
    List<GeoPoint> points,
    this.size, {
    GeoPoint? centre,
    this.padding = 32,
  }) {
    final reference =
        centre ?? (points.isEmpty ? const GeoPoint(0, 0) : points.first);
    final relative = [for (final p in points) _relative(p, reference)];
    if (centre == null && relative.isNotEmpty) {
      final xs = relative.map((o) => o.dx);
      final ys = relative.map((o) => o.dy);
      _centreX = (xs.reduce(min) + xs.reduce(max)) / 2;
      _centreY = (ys.reduce(min) + ys.reduce(max)) / 2;
    }
    _reference = reference;
    var halfX = _minHalfSpan;
    var halfY = _minHalfSpan;
    for (final o in relative) {
      halfX = max(halfX, (o.dx - _centreX).abs());
      halfY = max(halfY, (o.dy - _centreY).abs());
    }
    final usableX = max(1.0, size.width / 2 - padding);
    final usableY = max(1.0, size.height / 2 - padding);
    _scale = min(usableX / halfX, usableY / halfY);
  }

  /// Roughly 50 m: a single place is not blown up to fill the screen.
  static const _minHalfSpan = 0.0005;

  final Size size;
  final double padding;
  late final GeoPoint _reference;
  double _centreX = 0;
  double _centreY = 0;
  late final double _scale;

  Offset project(GeoPoint point) {
    final o = _relative(point, _reference);
    return Offset(
      size.width / 2 + (o.dx - _centreX) * _scale,
      size.height / 2 - (o.dy - _centreY) * _scale,
    );
  }

  /// The index of the point nearest [tap] within [radius] pixels, or null.
  /// Ties go to the lower index.
  int? hitTest(Offset tap, List<GeoPoint> points, {double radius = 24}) {
    int? best;
    var bestDistance = double.infinity;
    for (final (i, point) in points.indexed) {
      final distance = (project(point) - tap).distance;
      if (distance <= radius && distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Degrees east (scaled by latitude) and north of [reference].
  static Offset _relative(GeoPoint p, GeoPoint reference) {
    var dLon = p.longitude - reference.longitude;
    if (dLon > 180) dLon -= 360;
    if (dLon < -180) dLon += 360;
    final cosLat = max(0.01, cos(reference.latitude * pi / 180));
    return Offset(dLon * cosLat, p.latitude - reference.latitude);
  }
}
