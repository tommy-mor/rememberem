import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'street_map.dart';

/// A place's radius on the map: a tinted circle with an outline, drawn
/// under its pin.
class PlaceCircle extends CircleMarker {
  PlaceCircle({
    required GeoPoint at,
    required double meters,
    required ColorScheme scheme,
    bool selected = false,
  }) : super(
         point: StreetMap.latLng(at),
         radius: meters,
         useRadiusInMeter: true,
         color: scheme.primary.withValues(alpha: selected ? 0.22 : 0.10),
         borderColor: scheme.primary.withValues(alpha: selected ? 1 : 0.6),
         borderStrokeWidth: selected ? 2.5 : 1.5,
       );
}
