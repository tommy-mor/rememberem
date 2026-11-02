import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:rememberem_core/rememberem_core.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

/// Records what the screens ask to save, without image work: [prepare]
/// finds [faces] in a [width] x [height] photo and suggests [place] and
/// [meeting]; saving adds records as they are, uncropped.
class RecordingCapture extends PortraitCapture {
  RecordingCapture(
    MemoryRepository repository, {
    this.faces = const [],
    this.place = '',
    this.meeting = '',
    this.width = 400,
    this.height = 500,
  }) : super(
         repository: repository,
         faceLocator: _NoFaces(),
         workFolder: Directory.systemTemp,
       );

  final List<PixelRect> faces;
  final String place;
  final String meeting;
  final int width;
  final int height;

  /// When set, the group save fails on this face (counting from 0).
  int? failGroupAt;

  /// When set, the group save waits for this before saving anyone.
  Completer<void>? holdGroup;

  final calls = <({DateTime capturedAt, GeoPoint? location})>[];
  final savedFaces = <PixelRect?>[];

  @override
  Future<CaptureDraft> prepare(
    List<int> rawJpeg, {
    required DateTime capturedAt,
    GeoPoint? location,
    PlaceFinder? placeFinder,
    MeetingFinder? meetingFinder,
  }) async {
    calls.add((capturedAt: capturedAt, location: location));
    return CaptureDraft(
      photo: UprightPhoto(Uint8List.fromList(rawJpeg), width, height),
      faces: faces,
      capturedAt: capturedAt,
      location: location,
      place: place,
      meeting: meeting,
    );
  }

  @override
  Future<Memory> saveOne(CaptureDraft draft, {PixelRect? face}) {
    savedFaces.add(face);
    return repository.add(
      photoJpeg: draft.photo.jpeg,
      capturedAt: draft.capturedAt,
      location: draft.location,
      place: draft.place,
      meeting: draft.meeting,
    );
  }

  @override
  Future<List<Memory>> saveGroup(
    CaptureDraft draft,
    List<PixelRect> faces, {
    required String place,
    required String meeting,
    List<Detail> details = const [],
    void Function(Memory saved)? onSaved,
  }) async {
    await holdGroup?.future;
    final saved = <Memory>[];
    for (final (i, face) in faces.indexed) {
      if (i == failGroupAt) throw const FileSystemException('disk full');
      savedFaces.add(face);
      final memory = await repository.add(
        photoJpeg: draft.photo.jpeg,
        capturedAt: draft.capturedAt,
        location: draft.location,
        place: place.trim(),
        meeting: meeting.trim(),
        details: [
          for (final d in details)
            if (!d.isEmpty) d,
        ],
      );
      saved.add(memory);
      onSaved?.call(memory);
    }
    return saved;
  }
}
