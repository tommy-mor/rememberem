/// A distance as Fred reads it: feet and miles, or metres and kilometres.
class Distance {
  const Distance._();

  static const _metersPerFoot = 0.3048;
  static const _metersPerMile = 1609.344;

  /// "555 ft", "1.2 mi", "15 mi", or "170 m", "1.5 km", "15 km": short
  /// distances to the nearest 5, long ones to one decimal below 10.
  static String format(double meters, {required bool metric}) {
    if (metric) {
      if (meters < 1000) return '${_fives(meters)} m';
      return '${_decimal(meters / 1000)} km';
    }
    final feet = meters / _metersPerFoot;
    if (feet < 1000) return '${_fives(feet)} ft';
    return '${_decimal(meters / _metersPerMile)} mi';
  }

  static int _fives(double v) => (v / 5).round() * 5;

  static String _decimal(double v) =>
      v < 9.95 ? v.toStringAsFixed(1) : v.round().toString();
}
