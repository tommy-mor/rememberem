import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/link_opener.dart';

/// A pannable map with [markers]. With [streetMaps] on, streets come from
/// OpenStreetMap, which then sees the device's address and the area being
/// viewed (never names, photos or notes). Off, nothing is fetched and the
/// markers sit on a plain background.
class StreetMap extends StatefulWidget {
  const StreetMap({
    super.key,
    required this.streetMaps,
    required this.markers,
    required this.links,
    this.centre,
    this.fitAll = const [],
    this.onCentreChanged,
  });

  final bool streetMaps;

  /// Opens OpenStreetMap's copyright page from the credit on the map.
  final LinkOpener links;

  static final copyright = Uri.parse('https://www.openstreetmap.org/copyright');
  final List<Marker> markers;

  /// Where to look; the map moves there whenever this changes.
  final GeoPoint? centre;

  /// With no [centre], the first view fits all of these.
  final List<GeoPoint> fitAll;

  /// Called as the middle of the map moves (by a finger or otherwise).
  final ValueChanged<GeoPoint>? onCentreChanged;

  static const userAgentPackageName = 'com.rememberem.rememberem';
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static LatLng latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  State<StreetMap> createState() => _StreetMapState();
}

class _StreetMapState extends State<StreetMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(StreetMap old) {
    super.didUpdateWidget(old);
    final centre = widget.centre;
    if (_ready && centre != null && centre != old.centre) {
      _controller.move(StreetMap.latLng(centre), _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MapOptions get _options {
    final centre = widget.centre;
    final fit = widget.fitAll;
    final scheme = Theme.of(context).colorScheme;
    return MapOptions(
      backgroundColor: scheme.surfaceContainerHighest,
      initialCenter: centre != null
          ? StreetMap.latLng(centre)
          : const LatLng(0, 0),
      initialZoom: centre != null ? 16 : 2,
      initialCameraFit: centre == null && fit.isNotEmpty
          ? CameraFit.coordinates(
              coordinates: [for (final p in fit) StreetMap.latLng(p)],
              padding: const EdgeInsets.all(56),
              maxZoom: 16,
            )
          : null,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      onMapReady: () => _ready = true,
      onPositionChanged: widget.onCentreChanged == null
          ? null
          : (camera, _) => widget.onCentreChanged!(
              GeoPoint(camera.center.latitude, camera.center.longitude),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: _options,
      children: [
        if (widget.streetMaps)
          TileLayer(
            urlTemplate: StreetMap.tileUrl,
            userAgentPackageName: StreetMap.userAgentPackageName,
          ),
        MarkerLayer(markers: widget.markers),
        // Always in view, as OpenStreetMap's licence asks.
        if (widget.streetMaps)
          SimpleAttributionWidget(
            source: const Text('OpenStreetMap contributors'),
            onTap: () => widget.links.open(StreetMap.copyright),
          ),
      ],
    );
  }
}
