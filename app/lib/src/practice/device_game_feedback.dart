import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'game_feedback.dart';

/// Haptics and sounds on the phone, each only while its setting is on.
/// Sounds mix with whatever is playing and respect silent mode. Failures
/// are ignored: feedback must never get in the way of the game.
class DeviceGameFeedback implements GameFeedback {
  DeviceGameFeedback(this._settings);

  final ValueListenable<AppSettings> _settings;
  late final AudioPlayer _right = _player();
  late final AudioPlayer _wrong = _player();

  static AudioPlayer _player() => AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency).ignore()
    ..setAudioContext(
      AudioContextConfig(
        // Respecting silent mode is already "ambient" (mixing) on iOS, which
        // forbids asking again; on Android this takes no audio focus.
        focus: Platform.isIOS
            ? AudioContextConfigFocus.gain
            : AudioContextConfigFocus.mixWithOthers,
        respectSilence: true,
      ).build(),
    ).ignore();

  @override
  void right() {
    if (_settings.value.vibration) HapticFeedback.lightImpact().ignore();
    _play(_right, 'sounds/right.wav');
  }

  @override
  void wrong() => _play(_wrong, 'sounds/wrong.wav');

  void _play(AudioPlayer player, String asset) {
    if (!_settings.value.sounds) return;
    player.play(AssetSource(asset)).catchError((Object e) {
      debugPrint('Rememberem: sound failed: $e');
    });
  }
}
