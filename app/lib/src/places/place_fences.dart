import 'package:rememberem_core/rememberem_core.dart';

/// The phone's geofencing, as far as place notices need it.
abstract interface class PlaceFences {
  /// Watches exactly [fences], replacing any others.
  Future<void> sync(List<PlaceFence> fences);

  /// Watches nothing.
  Future<void> clear();
}
