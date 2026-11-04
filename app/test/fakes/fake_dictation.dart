import 'package:rememberem/src/speech/dictation.dart';

/// Dictation driven by the test: [say] plays words, [goQuiet] ends it,
/// [lackSpeechPack] ends it as a phone without offline speech would.
class FakeDictation implements Dictation {
  FakeDictation({this.available = true});

  final bool available;
  void Function(String words)? _onWords;
  void Function(String words)? _lastOnWords;
  void Function()? _onDone;
  void Function()? _onNoSpeechPack;

  bool get isListening => _onDone != null;

  /// How many times [stop] was called.
  int stops = 0;

  /// How many sessions [listen] started over one still listening; the
  /// real recogniser cannot, so callers must [stop] first.
  int startedOverLive = 0;

  @override
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
    void Function()? onNoSpeechPack,
  }) async {
    if (isListening) startedOverLive++;
    goQuiet();
    if (!available) {
      onDone();
      return false;
    }
    _onWords = onWords;
    _lastOnWords = onWords;
    _onDone = onDone;
    _onNoSpeechPack = onNoSpeechPack;
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    goQuiet();
  }

  void say(String words) => _onWords!(words);

  /// A result arriving after the session was stopped, as real recognisers
  /// sometimes deliver.
  void sayLate(String words) => _lastOnWords!(words);

  void lackSpeechPack() {
    final onNoSpeechPack = _onNoSpeechPack;
    goQuiet();
    onNoSpeechPack?.call();
  }

  void goQuiet() {
    final onDone = _onDone;
    _onWords = null;
    _onDone = null;
    _onNoSpeechPack = null;
    onDone?.call();
  }
}
