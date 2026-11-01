import 'package:rememberem_core/rememberem_core.dart';

import '../location/device_location.dart';
import '../speech/dictation.dart';

/// The long-lived services the screens share.
class AppServices {
  const AppServices({
    required this.repository,
    required this.capture,
    required this.dictation,
    required this.location,
  });

  final MemoryRepository repository;
  final PortraitCapture capture;
  final Dictation dictation;
  final DeviceLocation location;
}
