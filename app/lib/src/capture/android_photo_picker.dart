import 'package:flutter/services.dart';

import 'photo_picker.dart';

/// [PhotoPicker] for Android. The system photo picker strips GPS, so the
/// app's own channel (OriginalPhotoPicker.kt) asks for the original file.
class AndroidPhotoPicker implements PhotoPicker {
  static const _channel = MethodChannel(
    'com.rememberem.rememberem/original_photo',
  );

  @override
  Future<List<int>?> pick() => _channel.invokeMethod<Uint8List>('pick');
}
