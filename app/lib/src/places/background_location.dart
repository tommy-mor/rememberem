import 'location_ask.dart';

export 'location_ask.dart';

/// Location "all the time", which place notices need.
abstract interface class BackgroundLocation {
  /// True if the app may use location in the background. Throws if the
  /// phone could not say.
  Future<bool> granted();

  /// Asks for it: the system prompt, or the app's settings page, where
  /// Fred finishes and comes back.
  Future<LocationAsk> request();
}
