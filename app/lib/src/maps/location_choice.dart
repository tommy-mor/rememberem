import 'package:rememberem_core/rememberem_core.dart';

/// What Fred chose on the location picker: a point, or "Remote".
class LocationChoice {
  const LocationChoice.at(GeoPoint this.point) : remote = false;

  /// Met online: no location, so never matched to a real place.
  const LocationChoice.remote() : point = null, remote = true;

  final GeoPoint? point;
  final bool remote;

  /// Applies this choice to [encounter]. A real spot for a Remote
  /// encounter clears the Remote place, which must never have a location.
  Encounter applyTo(Encounter encounter) {
    if (remote) return encounter.asRemote();
    final located = encounter.withLocation(point);
    return encounter.place == Encounter.remotePlace
        ? located.withPlace('')
        : located;
  }
}
