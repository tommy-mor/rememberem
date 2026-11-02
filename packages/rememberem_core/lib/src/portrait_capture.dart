import 'dart:io';

import 'face_locator.dart';
import 'geo_point.dart';
import 'memory.dart';
import 'meeting_finder.dart';
import 'memory_repository.dart';
import 'place_finder.dart';
import 'portrait_cropper.dart';
import 'portrait_framer.dart';

/// Turns a freshly taken photo into a saved, head-and-shoulders [Memory].
class PortraitCapture {
  PortraitCapture({
    required this.repository,
    required this.faceLocator,
    required this.workFolder,
    this.framer = const PortraitFramer(),
    this.placeFinder = const PlaceFinder(),
    this.meetingFinder = const MeetingFinder(),
  });

  final MemoryRepository repository;
  final FaceLocator faceLocator;

  /// Scratch space for the upright copy handed to [faceLocator].
  final Directory workFolder;
  final PortraitFramer framer;
  final PlaceFinder placeFinder;
  final MeetingFinder meetingFinder;

  /// Crops [rawJpeg] to the largest face found. If there is no face the
  /// whole photo is kept, so the moment is never lost. The place is filled
  /// from the nearest known place, and the meeting from the one held there
  /// closest in time; both best effort.
  Future<Memory> capture(
    List<int> rawJpeg, {
    required DateTime capturedAt,
    GeoPoint? location,
  }) async {
    // Read known places now, so the lookup overlaps the slow photo work.
    final known = location == null ? null : _knownPeople();
    final photo = await PortraitCropper.uprightInBackground(rawJpeg);
    await workFolder.create(recursive: true);
    final uprightFile = File(
      '${workFolder.path}${Platform.pathSeparator}'
      'upright-${capturedAt.microsecondsSinceEpoch}.jpg',
    );
    await uprightFile.writeAsBytes(photo.jpeg, flush: true);
    try {
      final faces = await faceLocator.findFaces(uprightFile);
      final List<int> portrait;
      if (faces.isEmpty) {
        portrait = photo.jpeg;
      } else {
        final largest = faces.reduce((a, b) => a.area >= b.area ? a : b);
        final rect = framer.frame(largest, photo.width, photo.height);
        portrait = await PortraitCropper.cropInBackground(photo.jpeg, rect);
      }
      final people = await known;
      final place = location == null || people == null
          ? ''
          : placeFinder.nearest(location, people)?.place ?? '';
      final meeting = people == null || place.isEmpty
          ? ''
          : meetingFinder.suggest(place, capturedAt, people);
      return await repository.add(
        photoJpeg: portrait,
        capturedAt: capturedAt,
        location: location,
        place: place,
        meeting: meeting,
      );
    } finally {
      await uprightFile.delete();
    }
  }

  /// Everyone active, or null if they cannot be read: a failed lookup must
  /// never cost the photo.
  Future<List<Memory>?> _knownPeople() async {
    try {
      return await repository.all();
    } catch (_) {
      // Best effort: a corrupt or oddly shaped record (which may throw an
      // Error, not an Exception) just means no place is filled in.
      return null;
    }
  }
}
