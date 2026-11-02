import 'package:rememberem_core/rememberem_core.dart';

/// What Fred chose on the location picker: a point with the name of the
/// place there (blank if it is not a known place), or "Remote".
class LocationChoice {
  const LocationChoice.at(GeoPoint this.point, {this.place = ''})
    : remote = false;

  /// Met online: no location, so never matched to a real place.
  const LocationChoice.remote()
    : point = null,
      place = Encounter.remotePlace,
      remote = true;

  final GeoPoint? point;

  /// The known place at [point], Fred's name for the spot, or blank.
  final String place;
  final bool remote;

  /// Applies this choice to [encounter]: the new spot and the place there,
  /// so a picture never keeps the name of somewhere it no longer is.
  Encounter applyTo(Encounter encounter) {
    if (remote) return encounter.asRemote();
    return encounter.withLocation(point).withPlace(place);
  }
}
