import 'package:speech_to_text/speech_to_text.dart';

import 'dictation.dart';
import 'speech_transcript.dart';

/// [Dictation] using the phone's own speech recogniser, on the device
/// where the phone has an on-device recogniser (Android 12+), so the audio
/// stays on the phone. Without one, the plugin falls back to the phone's
/// default speech service, which may send the audio to be recognised.
class DeviceDictation implements Dictation {
  /// How long a silence ends the dictation.
  static const quietPause = Duration(seconds: 3);
  static const longestListen = Duration(minutes: 1);

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  void Function()? _onDone;
  void Function()? _onNoSpeechPack;

  /// The recogniser's errors for a language it has no offline speech for.
  static const _noSpeechPack = {
    'error_language_not_supported',
    'error_language_unavailable',
  };

  @override
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
    void Function()? onNoSpeechPack,
  }) async {
    _finish();
    if (!await _initialise()) {
      onDone();
      return false;
    }
    _onDone = onDone;
    _onNoSpeechPack = onNoSpeechPack;
    final transcript = SpeechTranscript();
    await _speech.listen(
      onResult: (result) => onWords(
        transcript.add(result.recognizedWords, isFinal: result.finalResult),
      ),
      listenOptions: SpeechListenOptions(
        listenFor: longestListen,
        pauseFor: quietPause,
        partialResults: true,
        listenMode: ListenMode.dictation,
        onDevice: true,
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
          onError: (error) {
            // Kept past [_finish]: the error can follow the "done" status.
            final noSpeechPack = _onNoSpeechPack;
            _onNoSpeechPack = null;
            if (_noSpeechPack.contains(error.errorMsg)) noSpeechPack?.call();
            _finish();
          },
        );
    return _ready;
  }

  void _finish() {
    final onDone = _onDone;
    _onDone = null;
    onDone?.call();
  }
}
