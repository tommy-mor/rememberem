/// Names for the pages that must not be opened twice on top of each
/// other: the camera, and a practice game.
class AppRoutes {
  const AppRoutes._();

  static const capture = 'capture';
  static const practice = 'practice';

  /// The list filtered to a place, opened from an arrival notice.
  static const placeAlert = 'place-alert';
}
