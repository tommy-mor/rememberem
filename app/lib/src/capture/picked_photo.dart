/// A photo Fred chose from the phone.
class PickedPhoto {
  const PickedPhoto(this.bytes, {this.original = true});

  /// The file's bytes, untouched apart from anything the phone removed.
  final List<int> bytes;

  /// False if the phone may have removed the photo's location, because
  /// Rememberem is not allowed to read photo locations.
  final bool original;
}
