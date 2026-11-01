import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late JsonFileMemoryRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rememberem_repo_');
    repository = JsonFileMemoryRepository(Directory('${temp.path}/memories'));
  });

  tearDown(() => temp.delete(recursive: true));

  test('add stores the photo and an empty record', () async {
    final memory = await repository.add(
      photoJpeg: [1, 2, 3],
      capturedAt: DateTime.utc(2026, 11, 1, 10),
      location: const GeoPoint(47.6, -122.3),
    );

    expect(await repository.photoFile(memory).readAsBytes(), [1, 2, 3]);
    final stored = (await repository.all()).single;
    expect(stored.id, memory.id);
    expect(stored.capturedAt, DateTime.utc(2026, 11, 1, 10));
    expect(stored.location, const GeoPoint(47.6, -122.3));
    expect(stored.fields, isEmpty);
  });

  test('save persists fields, including ones beyond the standard four',
      () async {
    final memory = await repository.add(
      photoJpeg: [1],
      capturedAt: DateTime.utc(2026, 11, 1),
    );

    await repository.save(memory
        .withField(MemoryField.name.key, 'Alex Davis')
        .withField('age', '34'));

    final stored = (await repository.all()).single;
    expect(stored.field(MemoryField.name), 'Alex Davis');
    expect(stored.fields['age'], '34');
    expect(stored.location, isNull);
  });

  test('all lists newest first and ignores leftover temp files', () async {
    await repository.add(photoJpeg: [1], capturedAt: DateTime.utc(2026, 1, 1));
    await repository.add(photoJpeg: [2], capturedAt: DateTime.utc(2026, 6, 1));
    await File('${repository.folder.path}/x.json.tmp').writeAsString('{');

    final dates = (await repository.all()).map((m) => m.capturedAt);

    expect(dates, [DateTime.utc(2026, 6, 1), DateTime.utc(2026, 1, 1)]);
  });

  test('all is empty before anything is stored', () async {
    expect(await repository.all(), isEmpty);
  });
}
