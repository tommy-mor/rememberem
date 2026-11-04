import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'place_marker_view.dart';
import 'street_map.dart';

/// A labelled pin for a place; its tip sits on the place.
class PlaceMarker extends Marker {
  PlaceMarker({
    required GeoPoint at,
    required String label,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
  }) : super(
         point: StreetMap.latLng(at),
         width: 160,
         height: 64,
         alignment: Alignment.topCenter,
         child: PlaceMarkerView(
           label,
           selected: selected,
           onTap: onTap,
           onDoubleTap: onDoubleTap,
           onLongPress: onLongPress,
         ),
       );
}
