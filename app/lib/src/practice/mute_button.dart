import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../settings/app_settings_controller.dart';

/// Turns the app's sounds off or on from a game: the same switch as
/// "Sounds" in Settings, so it is remembered and also quiets the dictation
/// dings. Vibration has its own switch and is not changed.
class MuteButton extends StatelessWidget {
  const MuteButton(this.settings, {super.key});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: settings,
      builder: (context, s, _) => IconButton(
        tooltip: s.sounds ? 'Mute sounds' : 'Unmute sounds',
        icon: Icon(s.sounds ? Icons.volume_up : Icons.volume_off),
        onPressed: () => settings.update(s.copyWith(sounds: !s.sounds)),
      ),
    );
  }
}
