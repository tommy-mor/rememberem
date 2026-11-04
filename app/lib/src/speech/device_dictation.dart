import 'dart:async';

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

  /// How long a session that has stopped listening waits for its final
  /// words (the plugin says "done" only once they have come).
  static const stopWait = Duration(milliseconds: 1500);

  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  void Function()? _onDone;
  void Function()? _onNoSpeechPack;

  /// Completes when the live session's [_finish] runs.
  Completer<void>? _finished;

  /// Ends a session whose "done" never comes.
  Timer? _fallback;

  /// Bumped by every [listen]: the plugin hands every result to its
  /// latest listener, so a late result of an ended session is dropped
  /// rather than landing in the next field.
  int _session = 0;

  /// The latest [listen]'s start-up; each waits for the one before, so a
  /// second mic tapped during the first's start (or its permission
  /// prompt) finds it running and ends it.
  Future<void> _starting = Future.value();

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
    final before = _starting;
    final started = Completer<void>();
    _starting = started.future;
    try {
      await before;
      return await _start(onWords, onDone, onNoSpeechPack);
    } finally {
      started.complete();
    }
  }

  Future<bool> _start(
    void Function(String words) onWords,
    void Function() onDone,
    void Function()? onNoSpeechPack,
  ) async {
    // A session still running is ended first, so its last words land in
    // its own field before this one starts.
    if (_onDone != null) await stop();
    if (!await _initialise()) {
      onDone();
      return false;
    }
    _onDone = onDone;
    _onNoSpeechPack = onNoSpeechPack;
    _finished = Completer<void>();
    final transcript = SpeechTranscript();
    final session = ++_session;
    await _speech.listen(
      onResult: (result) {
        if (session != _session) return;
        onWords(
          transcript.add(result.recognizedWords, isFinal: result.finalResult),
        );
      },
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

  /// Ends the session, waiting (up to [stopWait]) for the recogniser's
  /// final words and its "done", so they reach the session's own field.
  /// If they never come, the recogniser is cancelled, so it cannot run on
  /// into the next session.
  @override
  Future<void> stop() async {
    final finished = _finished;
    await _speech.stop();
    if (finished != null && !finished.isCompleted) {
      var late = false;
      await finished.future.timeout(stopWait, onTimeout: () => late = true);
      if (late) await _speech.cancel();
    }
    _finish();
  }

  Future<bool> _initialise() async {
    _ready =
        _ready ||
        await _speech.initialize(
          onStatus: (status) {
            // A late status of an ended session must not end the next.
            if (_onDone == null) return;
            if (status == SpeechToText.doneStatus) {
              _finish();
            } else if (status == SpeechToText.notListeningStatus) {
              // The final words may still be coming; "done" follows them.
              _fallback ??= Timer(stopWait, _finish);
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
    _fallback?.cancel();
    _fallback = null;
    final onDone = _onDone;
    final finished = _finished;
    _onDone = null;
    _finished = null;
    onDone?.call();
    if (finished != null && !finished.isCompleted) finished.complete();
  }
}
