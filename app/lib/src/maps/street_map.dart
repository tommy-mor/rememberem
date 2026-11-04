import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../about/link_opener.dart';

/// A pannable map with [markers] over [circles]. With [streetMaps] on,
/// streets come from
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
    this.circles = const [],
    this.focus,
    this.centreTick = 0,
    this.zoomTo,
  });

  final bool streetMaps;

  /// Opens OpenStreetMap's copyright page from the credit on the map.
  final LinkOpener links;

  static final copyright = Uri.parse('https://www.openstreetmap.org/copyright');
  final List<Marker> markers;

  /// Drawn under the markers, such as places' radii.
  final List<CircleMarker> circles;

  /// A circle to keep in view, such as a radius being adjusted. While not
  /// [settled] the map moves only if the circle no longer fits; once
  /// settled it fits the circle exactly.
  final ({GeoPoint at, double meters, bool settled})? focus;

  /// Where to look; the map moves there whenever this, or
  /// [centreTick], changes.
  final GeoPoint? centre;

  /// Bumped to look at [centre] again, though it has not changed.
  final int centreTick;

  /// Fits a circle of [meters] at [at] edge to edge, with no margin;
  /// each new [tick] fits again, though nothing else changed.
  final ({GeoPoint at, double meters, int tick})? zoomTo;

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
    final moved = centre != old.centre || widget.centreTick != old.centreTick;
    if (_ready && centre != null && moved) {
      _controller.move(StreetMap.latLng(centre), _controller.camera.zoom);
    }
    final focus = widget.focus;
    if (_ready && focus != null && focus != old.focus) _keepInView(focus);
    final zoom = widget.zoomTo;
    if (_ready && zoom != null && zoom != old.zoomTo) {
      _controller.fitCamera(
        CameraFit.bounds(bounds: _boundsOf(zoom.at, zoom.meters)),
      );
    }
  }

  /// While sliding, at most one refit per [_refitGap], so a long slide
  /// does not ask OpenStreetMap for a new set of tiles every frame.
  static const _refitGap = Duration(milliseconds: 250);
  Timer? _refit;

  void _keepInView(({GeoPoint at, double meters, bool settled}) focus) {
    if (focus.settled) {
      _refit?.cancel();
      _refit = null;
      _fit(focus);
      return;
    }
    _refit ??= Timer(_refitGap, () {
      _refit = null;
      final latest = widget.focus;
      if (!mounted || latest == null) return;
      final bounds = _boundsOf(latest.at, latest.meters);
      if (!_controller.camera.visibleBounds.containsBounds(bounds)) {
        _fit(latest);
      }
    });
  }

  void _fit(({GeoPoint at, double meters, bool settled}) focus) =>
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: _boundsOf(focus.at, focus.meters),
          padding: const EdgeInsets.all(24),
        ),
      );

  /// The square around a circle of [meters] at [at].
  static LatLngBounds _boundsOf(GeoPoint at, double meters) {
    const metersPerDegree = 111320.0;
    final dLat = meters / metersPerDegree;
    final cosLat = cos(at.latitude * pi / 180).abs().clamp(0.01, 1.0);
    final dLng = (meters / (metersPerDegree * cosLat)).clamp(0.0, 179.0);
    return LatLngBounds(
      LatLng(
        (at.latitude - dLat).clamp(-85, 85),
        (at.longitude - dLng).clamp(-180, 180),
      ),
      LatLng(
        (at.latitude + dLat).clamp(-85, 85),
        (at.longitude + dLng).clamp(-180, 180),
      ),
    );
  }

  @override
  void dispose() {
    _refit?.cancel();
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
        if (widget.circles.isNotEmpty) CircleLayer(circles: widget.circles),
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
