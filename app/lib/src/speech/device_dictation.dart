import 'package:speech_to_text/speech_to_text.dart';

import 'dictation.dart';

/// [Dictation] using the phone's own speech recogniser.
class DeviceDictation implements Dictation {
  /// How long a silence ends the dictation.
  static const quietPause = Duration(seconds: 3);
  static const longestListen = Duration(minutes: 1);

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  void Function()? _onDone;

  @override
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    _finish();
    if (!await _initialise()) {
      onDone();
      return false;
    }
    _onDone = onDone;
    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenFor: longestListen,
        pauseFor: quietPause,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _finish();
  }

  Future<bool> _initialise() async {
    _ready =
        _ready ||
        await _speech.initialize(
          onStatus: (status) {
            if (status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) {
              _finish();
            }
          },
          onError: (_) => _finish(),
        );
    return _ready;
  }

  void _finish() {
    final onDone = _onDone;
    _onDone = null;
    onDone?.call();
  }
}
