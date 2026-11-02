import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'photo_picker.dart';

/// [PhotoPicker] using the phone's own photo chooser.
class GalleryPhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<List<int>?> pick() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } finally {
      // The plugin copies the photo into the app's cache; remove that copy,
      // and never anything outside the cache (it could be Fred's own photo).
      final cache = (await getTemporaryDirectory()).absolute.path;
      final copy = File(file.path).absolute;
      if (copy.path.startsWith(cache)) {
        try {
          await copy.delete();
        } on FileSystemException {
          // Already gone.
        }
      }
    }
  }
}
