/// Which places start with their arrival notifications off: the ones
/// Fred is at every day, where a notice would only be noise.
class PlaceAlertDefaults {
  const PlaceAlertDefaults._();

  static const quietNames = {'home', 'work', 'church'};

  /// Whether [place] is quiet until Fred turns it on (trimmed, any case).
  static bool quiet(String place) =>
      quietNames.contains(place.trim().toLowerCase());
}
