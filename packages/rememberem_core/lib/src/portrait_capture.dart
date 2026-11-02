import 'dart:io';

import 'capture_draft.dart';
import 'detail.dart';
import 'face_locator.dart';
import 'geo_point.dart';
import 'memory.dart';
import 'meeting_finder.dart';
import 'memory_repository.dart';
import 'pixel_rect.dart';
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
  /// at that time of week; both best effort. [placeFinder] and
  /// [meetingFinder] override the defaults for this capture (settings).
  Future<Memory> capture(
    List<int> rawJpeg, {
    required DateTime capturedAt,
    GeoPoint? location,
    PlaceFinder? placeFinder,
    MeetingFinder? meetingFinder,
  }) async {
    final draft = await prepare(
      rawJpeg,
      capturedAt: capturedAt,
      location: location,
      placeFinder: placeFinder,
      meetingFinder: meetingFinder,
    );
    return saveOne(draft, face: draft.largestFace);
  }

  /// Makes [rawJpeg] upright, finds its faces and suggests a place and
  /// meeting, as [capture] does, without saving anything.
  Future<CaptureDraft> prepare(
    List<int> rawJpeg, {
    required DateTime capturedAt,
    GeoPoint? location,
    PlaceFinder? placeFinder,
    MeetingFinder? meetingFinder,
  }) async {
    // Read known places now, so the lookup overlaps the slow photo work.
    final known = location == null ? null : _knownPeople();
    final photo = await PortraitCropper.uprightInBackground(rawJpeg);
    await workFolder.create(recursive: true);
    final uprightFile = File(
      '${workFolder.path}${Platform.pathSeparator}'
      'upright-${capturedAt.microsecondsSinceEpoch}.jpg',
    );
    final List<PixelRect> faces;
    try {
      await uprightFile.writeAsBytes(photo.jpeg, flush: true);
      faces = [...await _findFaces(uprightFile)]..sort(
          (a, b) => a.left != b.left ? a.left - b.left : a.top - b.top,
        );
    } finally {
      await _deleteQuietly(uprightFile);
    }
    final people = await known;
    final place = location == null || people == null
        ? ''
        : (placeFinder ?? this.placeFinder).nearest(location, people)?.place ??
            '';
    final meeting = people == null || place.isEmpty
        ? ''
        : (meetingFinder ?? this.meetingFinder)
            .suggest(place, capturedAt, people);
    return CaptureDraft(
      photo: photo,
      faces: faces,
      capturedAt: capturedAt,
      location: location,
      place: place,
      meeting: meeting,
    );
  }

  /// Saves [draft] as one person, cropped to [face] (the whole photo if
  /// null), at the draft's place and meeting.
  Future<Memory> saveOne(CaptureDraft draft, {PixelRect? face}) async =>
      repository.add(
        photoJpeg: await _portrait(draft, face),
        capturedAt: draft.capturedAt,
        location: draft.location,
        place: draft.place,
        meeting: draft.meeting,
      );

  /// Saves one unnamed person per face in [faces], each cropped to its
  /// face, at [place] and [meeting], with [details] (blank ones dropped).
  /// Each person gets their own detail ids, so a later edit to one copy
  /// survives merging two of them.
  /// People are saved one at a time; if one fails, [onSaved] has already
  /// had everyone saved before it, and the error is rethrown.
  Future<List<Memory>> saveGroup(
    CaptureDraft draft,
    List<PixelRect> faces, {
    required String place,
    required String meeting,
    List<Detail> details = const [],
    void Function(Memory saved)? onSaved,
  }) async {
    final kept = [
      for (final d in details)
        if (!d.isEmpty) d
    ];
    final saved = <Memory>[];
    for (final (i, face) in faces.indexed) {
      final memory = await repository.add(
        photoJpeg: await _portrait(draft, face),
        capturedAt: draft.capturedAt,
        location: draft.location,
        place: place.trim(),
        meeting: meeting.trim(),
        details: [for (final d in kept) d.copyWith(id: '${d.id}-$i')],
      );
      saved.add(memory);
      onSaved?.call(memory);
    }
    return saved;
  }

  Future<List<int>> _portrait(CaptureDraft draft, PixelRect? face) async {
    final photo = draft.photo;
    if (face == null) return photo.jpeg;
    final rect = framer.frame(face, photo.width, photo.height);
    return PortraitCropper.cropInBackground(photo.jpeg, rect);
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Never written, or already gone.
    }
  }

  /// Faces in [photo], or none if finding them fails: a broken face finder
  /// must never cost the photo (it is then kept whole).
  Future<List<PixelRect>> _findFaces(File photo) async {
    try {
      return await faceLocator.findFaces(photo);
    } catch (_) {
      return const [];
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
