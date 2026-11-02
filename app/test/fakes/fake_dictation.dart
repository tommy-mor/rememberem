import 'package:rememberem/src/speech/dictation.dart';

/// Dictation driven by the test: [say] plays words, [goQuiet] ends it.
class FakeDictation implements Dictation {
  FakeDictation({this.available = true});

  final bool available;
  void Function(String words)? _onWords;
  void Function(String words)? _lastOnWords;
  void Function()? _onDone;

  bool get isListening => _onDone != null;

  @override
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    goQuiet();
    if (!available) {
      onDone();
      return false;
    }
    _onWords = onWords;
    _lastOnWords = onWords;
    _onDone = onDone;
    return true;
  }

  @override
  Future<void> stop() async => goQuiet();

  void say(String words) => _onWords!(words);

  /// A result arriving after the session was stopped, as real recognisers
  /// sometimes deliver.
  void sayLate(String words) => _lastOnWords!(words);

  void goQuiet() {
    final onDone = _onDone;
    _onWords = null;
    _onDone = null;
    onDone?.call();
  }
}
