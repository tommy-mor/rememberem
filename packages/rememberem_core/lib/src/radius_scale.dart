import 'dart:math';

/// The place radius slider: positions 0 to 1, logarithmic from 100 feet
/// to 100 miles, so each stretch of the slider multiplies the radius by
/// the same amount.
class RadiusScale {
  const RadiusScale._();

  /// 100 feet.
  static const minMeters = 30.48;

  /// 100 miles.
  static const maxMeters = 160934.4;

  static double metersAt(double position) {
    final t = position.clamp(0.0, 1.0);
    return minMeters * pow(maxMeters / minMeters, t);
  }

  static double positionOf(double meters) {
    final m = meters.clamp(minMeters, maxMeters);
    return log(m / minMeters) / log(maxMeters / minMeters);
  }
}
