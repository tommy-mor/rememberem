import 'package:flutter/foundation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../sound/app_sound.dart';
import '../sound/haptics.dart';
import '../sound/sounds.dart';
import 'game_feedback.dart';

/// A tap and a chime for a right answer, a "nope" for a wrong one, each
/// only while its setting is on.
class DeviceGameFeedback implements GameFeedback {
  DeviceGameFeedback(this._settings, this._sounds, this._haptics);

  final ValueListenable<AppSettings> _settings;
  final Sounds _sounds;
  final Haptics _haptics;

  @override
  void right() {
    if (_settings.value.vibration) _haptics.tap();
    _sounds.play(AppSound.right).ignore();
  }

  @override
  void wrong() => _sounds.play(AppSound.wrong).ignore();
}
