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

class _UnreadableRepository extends JsonFileMemoryRepository {
  _UnreadableRepository(super.folder);

  @override
  Future<List<Memory>> all() async =>
      throw const FormatException('corrupt record');
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

  test('keeps the whole photo when no face is found', () async {
    final memory = await captureWith(_FakeFaceLocator([]))
        .capture(jpeg(600, 800), capturedAt: DateTime.utc(2026, 11, 1));

    final photo = await storedPhoto(memory);
    expect([photo.width, photo.height], [600, 800]);
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

    test('no location, or only a trashed neighbour, gives a blank place',
        () async {
      final known = await knownCafe();

      expect((await captureAt(null)).latest.place, '');

      await repository.trash(known.id, DateTime.utc(2026, 10, 2));
      expect((await captureAt(nearby)).latest.place, '');
    });

    test('a record of the wrong shape (a TypeError) still saves the photo',
        () async {
      await knownCafe();
      await File('${temp.path}/memories/odd.json').writeAsString('[]');

      final memory = await captureAt(nearby);

      expect(memory.latest.place, '');
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
}
