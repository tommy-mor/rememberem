import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'app_sound.dart';
import 'sounds.dart';

/// [Sounds] through the phone's media volume, one ready player per sound.
/// Failures are ignored: a sound must never get in the way.
class DeviceSounds implements Sounds {
  DeviceSounds(this._settings);

  final ValueListenable<AppSettings> _settings;
  final Map<AppSound, Future<AudioPlayer>> _players = {};

  /// Media volume (the ringtone stream is silent on vibrate) without
  /// taking audio focus on Android; iOS's ambient mixes and respects the
  /// silent switch.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  @override
  Future<void> play(AppSound sound) async {
    if (!_settings.value.sounds) return;
    try {
      final player = await (_players[sound] ??= _load(sound));
      await player.stop();
      await player.resume();
    } catch (e) {
      _players.remove(sound); // try loading afresh next time
      debugPrint('Rememberem: sound failed: $e');
    }
  }

  static Future<AudioPlayer> _load(AppSound sound) async {
    final player = AudioPlayer();
    await player.setAudioContext(_context);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(sound.asset));
    return player;
  }
}
