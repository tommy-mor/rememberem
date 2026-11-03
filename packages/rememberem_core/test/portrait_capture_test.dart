import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

class _FakeFaceLocator implements FaceLocator {
  _FakeFaceLocator(this.faces);

  final List<PixelRect> faces;
  late img.Image seen;

  @override
  Future<List<PixelRect>> findFaces(File photo) async {
    seen = img.decodeJpg(await photo.readAsBytes())!;
    return faces;
  }
}

class _BrokenFaceLocator implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async =>
      throw StateError('face finder crashed');
}

class _UnreadableRepository extends JsonFileMemoryRepository {
  _UnreadableRepository(super.folder);

  @override
  Future<List<Memory>> all() async =>
      throw const FormatException('corrupt record');
}

/// Fails on the third add, as a full disk would.
class _FailingThirdAdd extends JsonFileMemoryRepository {
  _FailingThirdAdd(super.folder);

  int _adds = 0;

  @override
  Future<Memory> add({
    required List<int> photoJpeg,
    required DateTime capturedAt,
    GeoPoint? location,
    String place = '',
    String meeting = '',
    List<Detail> details = const [],
  }) {
    if (++_adds == 3) throw const FileSystemException('disk full');
    return super.add(
      photoJpeg: photoJpeg,
      capturedAt: capturedAt,
      location: location,
      place: place,
      meeting: meeting,
      details: details,
    );
  }
}

void main() {
  late Directory temp;
  late JsonFileMemoryRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rememberem_capture_');
    repository = JsonFileMemoryRepository(Directory('${temp.path}/memories'));
  });

  tearDown(() => temp.delete(recursive: true));

  PortraitCapture captureWith(FaceLocator locator) => PortraitCapture(
        repository: repository,
        faceLocator: locator,
        workFolder: Directory('${temp.path}/work'),
      );

  List<int> jpeg(int width, int height, {int orientation = 1}) {
    final image = img.Image(width: width, height: height);
    image.exif.imageIfd.orientation = orientation;
    return img.encodeJpg(image);
  }

  /// The DQT segments of [jpeg]: the tables its quality setting chose.
  List<List<int>> quantisationTables(List<int> jpeg) {
    final tables = <List<int>>[];
    var i = 2; // after SOI
    while (i + 4 <= jpeg.length && jpeg[i] == 0xFF) {
      final marker = jpeg[i + 1];
      final length = (jpeg[i + 2] << 8) | jpeg[i + 3];
      if (marker == 0xDB) tables.add(jpeg.sublist(i + 4, i + 2 + length));
      if (marker == 0xDA) break; // image data follows
      i += 2 + length;
    }
    return tables;
  }

  /// The tables this encoder writes at [quality].
  List<List<int>> qualityTables(int quality) => quantisationTables(
        img.encodeJpg(img.Image(width: 8, height: 8), quality: quality),
      );

  Future<img.Image> storedPhoto(Memory memory) async =>
      img.decodeJpg(await repository.photoFile(memory).readAsBytes())!;

  test('crops to head and shoulders around the largest face', () async {
    final small = const PixelRect(10, 10, 20, 20);
    final large = const PixelRect(100, 100, 80, 100);
    final capture = captureWith(_FakeFaceLocator([small, large]));

    final memory = await capture.capture(
      jpeg(600, 800),
      capturedAt: DateTime.utc(2026, 11, 1),
      location: const GeoPoint(1, 2),
    );

    final expected = const PortraitFramer().frame(large, 600, 800);
    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [expected.width, expected.height]);
    expect(memory.location, const GeoPoint(1, 2));
  });

  test('a crashing face finder still saves the whole photo', () async {
    final memory = await captureWith(_BrokenFaceLocator())
        .capture(jpeg(600, 800), capturedAt: DateTime.utc(2026, 11, 1));

    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [600, 800]);
  });

  test('keeps the whole photo when no face is found', () async {
    final memory = await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(600, 800), capturedAt: DateTime.utc(2026, 11, 1));

    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [600, 800]);
  });

  test('a large whole photo is shrunk to 1000 px on its longest side',
      () async {
    final memory = await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(3000, 4000), capturedAt: DateTime.utc(2026, 11, 1));

    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [750, 1000]);
  });

  test('a large landscape photo is shrunk to 1000 px wide', () async {
    final memory = await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(4000, 3000), capturedAt: DateTime.utc(2026, 11, 1));

    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [1000, 750]);
  });

  test('a small landscape photo keeps its size', () async {
    final memory = await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(800, 600), capturedAt: DateTime.utc(2026, 11, 1));

    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [800, 600]);
  });

  test('a whole photo is kept at JPEG quality 75', () async {
    final memory = await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(600, 800), capturedAt: DateTime.utc(2026, 11, 1));

    final bytes = await repository.photoFile(memory).readAsBytes();
    expect(quantisationTables(bytes), qualityTables(75));
  });

  test('a large face crop is shrunk and kept at JPEG quality 75', () async {
    final image = img.Image(width: 3000, height: 4000);
    for (final pixel in image) {
      pixel
        ..r = pixel.x % 256
        ..g = pixel.y % 256
        ..b = (pixel.x * pixel.y) % 256;
    }
    final memory = await captureWith(
      _FakeFaceLocator([const PixelRect(1000, 1000, 1000, 1000)]),
    ).capture(img.encodeJpg(image), capturedAt: DateTime.utc(2026, 11, 1));

    final bytes = await repository.photoFile(memory).readAsBytes();
    final photo = img.decodeJpg(bytes)!;
    expect(photo.width > photo.height ? photo.width : photo.height, 1000);
    // The quantisation tables are what the quality setting chooses.
    expect(quantisationTables(bytes), qualityTables(75));
    expect(quantisationTables(bytes), isNot(qualityTables(90)));
  });

  test('rotates the photo upright before looking for faces', () async {
    final locator = _FakeFaceLocator([]);

    await captureWith(locator).capture(
      jpeg(600, 800, orientation: 6),
      capturedAt: DateTime.utc(2026, 11, 1),
    );

    expect([locator.seen.width, locator.seen.height], [800, 600]);
  });

  test('cleans up its scratch file', () async {
    await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(60, 80), capturedAt: DateTime.utc(2026, 11, 1));

    expect(Directory('${temp.path}/work').listSync(), isEmpty);
  });

  group('place auto-fill', () {
    const cafe = GeoPoint(47.6, -122.3);
    // About 50 m north of the cafe.
    const nearby = GeoPoint(47.60045, -122.3);

    Future<Memory> knownCafe() async {
      final memory = await repository.add(
        photoJpeg: jpeg(10, 10),
        capturedAt: DateTime.utc(2026, 10, 1),
        location: cafe,
      );
      final named = memory.withField('place', 'Cafe');
      await repository.save(named);
      return named;
    }

    Future<Memory> captureAt(GeoPoint? location) =>
        captureWith(_FakeFaceLocator([])).capture(
          jpeg(60, 80),
          capturedAt: DateTime.utc(2026, 11, 1),
          location: location,
        );

    test('a capture near a known place starts with that place', () async {
      await knownCafe();

      final memory = await captureAt(nearby);

      expect(memory.latest.place, 'Cafe');
      final saved =
          (await repository.all()).firstWhere((m) => m.id == memory.id);
      expect(saved.latest.place, 'Cafe');
    });

    test('a meeting at that place within two hours is filled in too', () async {
      final memory = await repository.add(
        photoJpeg: jpeg(10, 10),
        capturedAt:
            DateTime.utc(2026, 11, 1).subtract(const Duration(minutes: 20)),
        location: cafe,
        place: 'Cafe',
        meeting: 'Standup',
      );
      expect(memory.latest.meeting, 'Standup');

      final captured = await captureAt(nearby);

      expect(captured.latest.place, 'Cafe');
      expect(captured.latest.meeting, 'Standup');
    });

    test("a trashed person's meeting is not used", () async {
      await repository.add(
        photoJpeg: jpeg(10, 10),
        capturedAt: DateTime.utc(2026, 10, 1),
        location: cafe,
        place: 'Cafe',
      );
      final gone = await repository.add(
        photoJpeg: jpeg(10, 10),
        capturedAt:
            DateTime.utc(2026, 11, 1).subtract(const Duration(minutes: 5)),
        location: cafe,
        place: 'Cafe',
        meeting: 'Secret',
      );
      await repository.trash(gone.id, DateTime.utc(2026, 11, 1));

      final captured = await captureAt(nearby);

      expect(captured.latest.place, 'Cafe');
      expect(captured.latest.meeting, '');
    });

    test('a nearby meeting is not used when no place was found', () async {
      await repository.add(
        photoJpeg: jpeg(10, 10),
        capturedAt: DateTime.utc(2026, 11, 1),
        location: cafe,
        place: 'Cafe',
        meeting: 'Standup',
      );

      expect((await captureAt(null)).latest.meeting, '');
    });

    test('no location, or only a trashed neighbour, gives a blank place',
        () async {
      final known = await knownCafe();

      expect((await captureAt(null)).latest.place, '');

      await repository.trash(known.id, DateTime.utc(2026, 10, 2));
      expect((await captureAt(nearby)).latest.place, '');
    });

    test('a record of the wrong shape (a TypeError) is passed over', () async {
      await knownCafe();
      await File('${temp.path}/memories/odd.json').writeAsString('[]');

      final memory = await captureAt(nearby);

      expect(memory.latest.place, 'Cafe');
      expect(await repository.photoFile(memory).exists(), isTrue);
    });

    test('a failed lookup still saves the photo, with a blank place', () async {
      repository = _UnreadableRepository(Directory('${temp.path}/memories'));

      final memory = await captureAt(nearby);

      expect(memory.encounters, hasLength(1));
      expect(memory.latest.place, '');
      expect(await repository.photoFile(memory).exists(), isTrue);
    });
  });

  group('several faces', () {
    const left = PixelRect(40, 300, 80, 100);
    const right = PixelRect(400, 100, 120, 150);
    const middle = PixelRect(200, 200, 60, 80);

    test('prepare saves nothing, sorts faces left to right and cleans up',
        () async {
      final draft = await captureWith(_FakeFaceLocator([right, left, middle]))
          .prepare(jpeg(600, 800), capturedAt: DateTime.utc(2026, 11, 1));

      expect(draft.faces, [left, middle, right]);
      expect(draft.largestFace, right);
      expect(await repository.all(), isEmpty);
      expect(Directory('${temp.path}/work').listSync(), isEmpty);
    });

    test('a broken face finder still cleans up and gives no faces', () async {
      final draft = await captureWith(_BrokenFaceLocator())
          .prepare(jpeg(60, 80), capturedAt: DateTime.utc(2026, 11, 1));

      expect(draft.faces, isEmpty);
      expect(Directory('${temp.path}/work').listSync(), isEmpty);
    });

    test('saveOne crops to the chosen face, not the largest', () async {
      final capture = captureWith(_FakeFaceLocator([left, right]));
      final draft = await capture.prepare(
        jpeg(600, 800),
        capturedAt: DateTime.utc(2026, 11, 1),
      );

      final memory = await capture.saveOne(draft, face: left);

      final expected = const PortraitFramer().frame(left, 600, 800);
      final photo = await storedPhoto(memory);
      expect([photo.width, photo.height], [expected.width, expected.height]);
    });

    test(
        'saveGroup makes one unnamed person per face, each with the place, '
        'meeting and non-blank details', () async {
      final capture = captureWith(_FakeFaceLocator([left, right]));
      final draft = await capture.prepare(
        jpeg(600, 800),
        capturedAt: DateTime.utc(2026, 11, 1),
        location: const GeoPoint(1, 2),
      );
      final at = DateTime.utc(2026, 11, 1, 9);

      final saved = await capture.saveGroup(
        draft,
        [left, right],
        place: ' Hall ',
        meeting: 'Choir',
        details: [
          Detail(id: 'd0', text: 'Sings tenor', at: at, type: DetailKind.fact),
          Detail(id: 'd1', text: '  ', at: at, type: DetailKind.fact),
        ],
      );

      final everyone = await repository.all();
      expect(everyone, hasLength(2));
      expect(saved.map((m) => m.id).toSet(), everyone.map((m) => m.id).toSet());
      // Each person's copy has its own id, so a merge keeps an edited copy.
      expect(saved.map((m) => m.details.single.id).toSet(), hasLength(2));
      for (final (i, face) in [left, right].indexed) {
        final m = everyone.firstWhere((m) => m.id == saved[i].id);
        expect(m.displayName, Memory.unknownName);
        expect(m.latest.place, 'Hall');
        expect(m.latest.meeting, 'Choir');
        expect(m.location, const GeoPoint(1, 2));
        expect(m.details.map((d) => d.text), ['Sings tenor']);
        final expected = const PortraitFramer().frame(face, 600, 800);
        final photo = await storedPhoto(m);
        expect([photo.width, photo.height], [expected.width, expected.height]);
      }
    });

    test('a failure partway keeps everyone saved before it', () async {
      repository = _FailingThirdAdd(Directory('${temp.path}/memories'));
      final capture = captureWith(_FakeFaceLocator([left, middle, right]));
      final draft = await capture.prepare(
        jpeg(600, 800),
        capturedAt: DateTime.utc(2026, 11, 1),
      );
      final reported = <Memory>[];

      await expectLater(
        capture.saveGroup(
          draft,
          [left, middle, right],
          place: 'Hall',
          meeting: '',
          details: [
            Detail(id: 'd0', text: 'Tall', at: DateTime.utc(2026)),
          ],
          onSaved: reported.add,
        ),
        throwsA(isA<FileSystemException>()),
      );

      final everyone = await repository.all();
      expect(everyone, hasLength(2));
      expect(reported, hasLength(2));
      for (final m in everyone) {
        expect(m.latest.place, 'Hall');
        expect(m.details.single.text, 'Tall');
      }
    });
  });
}
