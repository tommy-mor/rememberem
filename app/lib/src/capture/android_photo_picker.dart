import 'package:flutter/services.dart';

import 'photo_picker.dart';
import 'picked_photo.dart';

/// [PhotoPicker] for Android, through the phone's own gallery picker
/// (OriginalPhotoPicker.kt), which asks for the original file so the
/// photo keeps its location.
class AndroidPhotoPicker implements PhotoPicker {
  static const _channel = MethodChannel(
    'com.rememberem.rememberem/original_photo',
  );

  @override
  Future<PickedPhoto?> pick() async {
    final result = await _channel.invokeMapMethod<String, Object?>('pick');
    if (result == null) return null;
    return PickedPhoto(
      result['bytes']! as Uint8List,
      original: result['original'] == true,
    );
  }

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
}
