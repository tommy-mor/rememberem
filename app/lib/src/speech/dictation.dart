/// Speech-to-text for filling in a text field.
abstract interface class Dictation {
  /// Listens until the speaker goes quiet, passing the words heard so far
  /// to [onWords] as they arrive and calling [onDone] once at the end.
  ///
  /// Starting a new session ends any earlier one. Returns false (after
  /// calling [onDone]) if speech recognition is unavailable or not allowed.
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
  });

  Future<void> stop();
}
