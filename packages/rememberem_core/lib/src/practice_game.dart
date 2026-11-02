/// The practice games a reminder can open.
enum PracticeGame {
  faces('faces'),
  details('details');

  const PracticeGame(this.wireId);

  /// What a notification carries: the game, and nothing about anyone.
  final String wireId;

  /// The game for [wireId], or null for anything unknown (payloads come
  /// from outside the app and are untrusted).
  static PracticeGame? fromWireId(String? wireId) {
    for (final game in values) {
      if (game.wireId == wireId) return game;
    }
    return null;
  }
}
