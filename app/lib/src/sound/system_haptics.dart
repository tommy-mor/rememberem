import 'package:flutter/services.dart';

import 'haptics.dart';

/// [Haptics] through the platform's own haptic feedback (iOS).
class SystemHaptics implements Haptics {
  @override
  void tap() => HapticFeedback.lightImpact().ignore();
}
