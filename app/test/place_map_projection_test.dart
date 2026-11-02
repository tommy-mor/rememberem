import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/places/place_map_projection.dart';
import 'package:rememberem_core/rememberem_core.dart';

void main() {
  const size = Size(400, 300);

  bool inside(Offset o) =>
      o.dx.isFinite &&
      o.dy.isFinite &&
      o.dx >= 0 &&
      o.dx <= size.width &&
      o.dy >= 0 &&
      o.dy <= size.height;

  test('one point sits in the middle', () {
    final projection = PlaceMapProjection([const GeoPoint(47.6, -122.3)], size);

    expect(
      projection.project(const GeoPoint(47.6, -122.3)),
      const Offset(200, 150),
    );
  });

  test('identical points and the antimeridian stay finite and on screen', () {
    const points = [
      GeoPoint(10, 179.999),
      GeoPoint(10, -179.999),
      GeoPoint(10, 179.999),
    ];
    final projection = PlaceMapProjection(points, size);

    for (final p in points) {
      expect(inside(projection.project(p)), isTrue, reason: '$p');
    }
    // Across the antimeridian the two are close, not a world apart.
    final gap = (projection.project(points[0]) - projection.project(points[1]))
        .distance;
    expect(gap, lessThan(size.width));
  });

  test('centring puts the chosen point mid-view with every point visible', () {
    const points = [
      GeoPoint(0, 0),
      GeoPoint(0.01, 0.01),
      GeoPoint(-0.02, 0.005),
    ];

    final projection = PlaceMapProjection(points, size, centre: points[1]);

    expect(projection.project(points[1]), const Offset(200, 150));
    for (final p in points) {
      expect(inside(projection.project(p)), isTrue);
    }
  });

  test('hitTest finds the nearest dot within reach, else nothing', () {
    const points = [GeoPoint(0, 0), GeoPoint(0.01, 0.01)];
    final projection = PlaceMapProjection(points, size);
    final second = projection.project(points[1]);

    expect(projection.hitTest(second + const Offset(5, 5), points), 1);
    expect(projection.hitTest(const Offset(-500, -500), points), isNull);
  });
}
