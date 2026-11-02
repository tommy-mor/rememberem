import 'picked_photo.dart';

/// Lets Fred choose a photo already on the phone instead of taking one.
abstract interface class PhotoPicker {
  /// The chosen photo (EXIF included where allowed), or null if Fred
  /// changed his mind. Leaves no copy behind.
  Future<PickedPhoto?> pick();

  /// Opens the phone's settings page for Rememberem, where Fred can allow
  /// photo locations.
  Future<void> openSettings();
}
