import '../sound/app_sound.dart';
import '../sound/sounds.dart';
import 'dictation.dart';

/// [Dictation] that dings as listening starts and again as it ends, so
/// Fred knows when to speak without looking.
class CuedDictation implements Dictation {
  CuedDictation(
    this._inner,
    this._sounds, {
    this.settle = const Duration(milliseconds: 200),
  });

  final Dictation _inner;
  final Sounds _sounds;

  /// The pause after the start ding, so the recogniser does not hear it.
  final Duration settle;

  /// Bumped by every [listen] and [stop]; a start still waiting for its
  /// ding sees the change and never begins listening.
  int _session = 0;

  /// The session [stop] ended, whose waiting start owes a stop ding; a
  /// session replaced by a newer [listen] ends silently.
  int? _stopped;

  /// The session the recogniser is listening for, until it ends; null
  /// when none is (a session still in its start ding is not live).
  int? _live;

  @override
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
    void Function()? onNoSpeechPack,
  }) async {
    // The newest tap wins, so the session is claimed before any wait.
    final session = ++_session;
    // Another field's mic is still on: end it first, so its last words
    // land there, then start this one.
    if (_live != null) await _inner.stop();
    await _sounds.play(AppSound.listenStart);
    await Future<void>.delayed(settle);
    var ended = false;
    void end({bool ding = true}) {
      if (ended) return;
      ended = true;
      if (_live == session) _live = null;
      if (ding) _sounds.play(AppSound.listenStop).ignore();
      onDone();
    }

    if (session != _session) {
      // Stopped, or replaced by a newer listen, before listening began.
      end(ding: _stopped == session);
      return true;
    }
    _live = session;
    return _inner.listen(
      onWords: onWords,
      onDone: end,
      onNoSpeechPack: onNoSpeechPack,
    );
  }

  @override
  Future<void> stop() {
    _stopped = _session;
    _session++;
    return _inner.stop();
  }
}
