import 'dart:convert';
import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late JsonFileMemoryRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rememberem_trash_');
    repository = JsonFileMemoryRepository(temp);
  });

  tearDown(() => temp.delete(recursive: true));

  Future<Memory> person(String name, DateTime capturedAt) async {
    final memory = await repository.add(
      photoJpeg: [1, 2, 3],
      capturedAt: capturedAt,
      location: const GeoPoint(47.6, -122.3),
    );
    final named = memory.withField('name', name).withDetails([
      Detail(id: 'd', text: 'Tall', at: DateTime.utc(2026, 1, 1)),
    ]);
    await repository.save(named);
    return named;
  }

  List<String> filesOf(String id) => [
        for (final f in temp.listSync())
          if (f.uri.pathSegments.last.startsWith('$id.'))
            f.uri.pathSegments.last,
      ];

  test('trash hides a person from all() and restore brings them back intact',
      () async {
    final alex = await person('Alex', DateTime.utc(2026, 11, 1));

    await repository.trash(alex.id, DateTime.utc(2026, 11, 2));

    expect(await repository.all(), isEmpty);
    final trashed = (await repository.trashed()).single;
    expect(trashed.trashedAt, DateTime.utc(2026, 11, 2));
    final original = alex.toJson();
    final after = trashed.toJson()..remove('trashedAt');
    expect(jsonEncode(after), jsonEncode(original));
    expect(await repository.photoFile(trashed).readAsBytes(), [1, 2, 3]);

    await repository.restore(alex.id);

    expect(
      jsonEncode((await repository.all()).single),
      jsonEncode(original),
    );
    expect(await repository.trashed(), isEmpty);
  });

  test('records without trashedAt load as active', () {
    final memory = Memory.fromJson({
      'id': 'old',
      'photo': 'old.jpg',
      'capturedAt': '2026-10-01T09:00:00.000Z',
    });

    expect(memory.trashedAt, isNull);
  });

  test('trashed() lists the most recently trashed first', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1));
    final b = await person('B', DateTime.utc(2026, 1, 2));

    await repository.trash(b.id, DateTime.utc(2026, 3, 1));
    await repository.trash(a.id, DateTime.utc(2026, 4, 1));

    expect((await repository.trashed()).map((m) => m.id), [a.id, b.id]);
  });

  test('purge removes every file for that person and nothing else', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1));
    final b = await person('B', DateTime.utc(2026, 1, 2));
    await File('${temp.path}/${a.id}.jpg.tmp').writeAsString('partial');
    await repository.trash(a.id, DateTime.utc(2026, 2, 1));

    await repository.purge(a.id);
    await repository.purge(a.id); // safe to repeat

    expect(filesOf(a.id), isEmpty);
    expect(filesOf(b.id), unorderedEquals(['${b.id}.jpg', '${b.id}.json']));
  });

  test('purge works even when the record is corrupt', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1));
    await File('${temp.path}/${a.id}.json').writeAsString('{not json');

    await repository.purge(a.id);

    expect(filesOf(a.id), isEmpty);
  });

  test('purge leaves people whose id merely starts with the same text',
      () async {
    final a = Memory.captured(
        trashedAt: DateTime.utc(2026),
        id: 'abc',
        photoFileName: 'abc.jpg',
        capturedAt: DateTime.utc(2026));
    final b = Memory.captured(
        id: 'abc-2',
        photoFileName: 'abc-2.jpg',
        capturedAt: DateTime.utc(2026));
    for (final m in [a, b]) {
      await File('${temp.path}/${m.id}.json').writeAsString(jsonEncode(m));
      await File('${temp.path}/${m.id}.jpg').writeAsBytes([1]);
    }

    await repository.purge('abc');

    expect(filesOf('abc-2'), unorderedEquals(['abc-2.jpg', 'abc-2.json']));
    expect(File('${temp.path}/abc.json').existsSync(), isFalse);
  });

  test('a stale save neither untrashes nor recreates a purged person',
      () async {
    final alex = await person('Alex', DateTime.utc(2026, 11, 1));
    final stale = alex.withField('name', 'Alex Davis'); // trashedAt null

    await repository.trash(alex.id, DateTime.utc(2026, 11, 2));
    await repository.save(stale);

    final trashed = (await repository.trashed()).single;
    expect(trashed.field(MemoryField.name), 'Alex Davis');
    expect(trashed.trashedAt, isNotNull);
    expect(await repository.all(), isEmpty);

    await repository.purge(alex.id);
    await expectLater(repository.save(stale), throwsStateError);
    expect(filesOf(alex.id), isEmpty);
  });

  test('a save still in flight cannot undo a trash that follows it', () async {
    final alex = await person('Alex', DateTime.utc(2026, 11, 1));

    final saving = repository.save(alex.withField('name', 'Alex Davis'));
    final trashing = repository.trash(alex.id, DateTime.utc(2026, 11, 2));
    await Future.wait([saving, trashing]);

    expect(await repository.all(), isEmpty);
    expect((await repository.trashed()).single.field(MemoryField.name),
        'Alex Davis');
  });

  test('one failed mutation does not block the ones after it', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1));
    final b = await person('B', DateTime.utc(2026, 1, 2));
    await repository.trash(a.id, DateTime.utc(2026, 2, 1));
    await repository.purge(a.id);

    await expectLater(repository.save(a), throwsStateError);
    await repository.trash(b.id, DateTime.utc(2026, 3, 1));
    final c = await person('C', DateTime.utc(2026, 1, 3));

    expect((await repository.trashed()).single.id, b.id);
    expect((await repository.all()).single.id, c.id);
  });

  test('purge refuses someone who is not in the trash', () async {
    final alex = await person('Alex', DateTime.utc(2026, 11, 1));

    await expectLater(repository.purge(alex.id), throwsStateError);

    expect(filesOf(alex.id), hasLength(2));
    expect((await repository.all()).single.id, alex.id);
  });
}
