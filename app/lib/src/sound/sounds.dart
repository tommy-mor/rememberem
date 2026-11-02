import 'app_sound.dart';

/// Plays the app's short sounds: game chimes and dictation dings.
abstract interface class Sounds {
  /// Plays [sound] once, if Fred has sounds on. Completes once it has
  /// started (or failed, or is off); never throws.
  Future<void> play(AppSound sound);
}
