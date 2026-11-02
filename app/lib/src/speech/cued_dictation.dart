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

  @override
  Future<bool> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    final session = ++_session;
    await _sounds.play(AppSound.listenStart);
    await Future<void>.delayed(settle);
    var ended = false;
    void end({bool ding = true}) {
      if (ended) return;
      ended = true;
      if (ding) _sounds.play(AppSound.listenStop).ignore();
      onDone();
    }

    if (session != _session) {
      // Stopped, or replaced by a newer listen, before listening began.
      end(ding: _stopped == session);
      return true;
    }
    return _inner.listen(onWords: onWords, onDone: end);
  }

  @override
  Future<void> stop() {
    _stopped = _session;
    _session++;
    return _inner.stop();
  }
}
