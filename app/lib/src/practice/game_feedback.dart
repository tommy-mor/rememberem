/// What Fred feels and hears when he answers in a practice game.
abstract interface class GameFeedback {
  /// A right answer: a light tap and a little chime.
  void right();

  /// A wrong answer: a tiny "nope".
  void wrong();
}
