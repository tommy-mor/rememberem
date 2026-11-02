/// Lets Fred choose a photo already on the phone instead of taking one.
abstract interface class PhotoPicker {
  /// The chosen photo's bytes, untouched (EXIF included), or null if Fred
  /// changed his mind. Leaves no copy behind.
  Future<List<int>?> pick();
}
