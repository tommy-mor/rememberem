import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptics.dart';

/// [Haptics] through the phone's vibrator (Haptics.kt). Flutter's own
/// haptic feedback follows the "touch interactions" system setting, which
/// many phones ship turned off.
class AndroidHaptics implements Haptics {
  static const _channel = MethodChannel('com.rememberem.rememberem/haptics');

  @override
  void tap() => _channel.invokeMethod<void>('tap').catchError((Object e) {
    debugPrint('Rememberem: vibration failed: $e');
  });
}
