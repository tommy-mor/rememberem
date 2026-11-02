import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

GeoPoint north(double meters) => GeoPoint(meters / 111194.93, 0);

/// Fails the save of one chosen person, once.
class _FailOnce extends JsonFileMemoryRepository {
  _FailOnce(super.folder, this.failId);

  String? failId;

  @override
  Future<void> save(Memory memory) {
    if (memory.id == failId) {
      failId = null;
      throw const FileSystemException('disk full');
    }
    return super.save(memory);
  }
}

void main() {
  late Directory temp;
  late JsonFileMemoryRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rememberem_rename_');
    repository = JsonFileMemoryRepository(temp);
  });

  tearDown(() => temp.delete(recursive: true));

  /// A person with the given encounters, saved through the repository.
  Future<Memory> person(List<Encounter> encounters,
      {bool trashed = false}) async {
    final added =
        await repository.add(photoJpeg: [1], capturedAt: DateTime.utc(2026));
    final memory = added.withEncounters(encounters);
    await repository.save(memory);
    if (trashed) await repository.trash(memory.id, DateTime.utc(2026, 6, 1));
    return memory;
  }

  Encounter met(String photo, String place, GeoPoint? location,
          {int day = 1, String meeting = ''}) =>
      Encounter(
        photoFileName: photo,
        capturedAt: DateTime.utc(2026, 1, day),
        location: location,
        place: place,
        meeting: meeting,
      );

  Future<PlaceGroup> groupLabelled(String label, {int skip = 0}) async =>
      PlaceBook.from(await repository.all())
          .groups
          .where((g) => g.label == label)
          .skip(skip)
          .first;

  Future<Memory> reload(String id) async => [
        ...await repository.all(),
        ...await repository.trashed()
      ].firstWhere((m) => m.id == id);

  test(
      'a named place is renamed on every matching encounter, trashed '
      'people included; nothing else changes', () async {
    final p1 = await person([
      met('a.jpg', 'Cafe ', north(0), meeting: 'Lunch'),
      met('b.jpg', 'Park', north(5000), day: 2),
      met('c.jpg', '', north(9000), day: 3),
    ]);
    final p2 = await person([met('d.jpg', 'Cafe', north(1))], trashed: true);

    await PlaceRenamer(repository)
        .rename(await groupLabelled('Cafe'), ' Diner ');

    final one = {
      for (final e in (await reload(p1.id)).encounters) e.photoFileName: e
    };
    expect(one['a.jpg']!.place, 'Diner');
    expect(one['a.jpg']!.meeting, 'Lunch');
    expect(one['a.jpg']!.capturedAt, DateTime.utc(2026, 1, 1));
    expect(one['a.jpg']!.location, north(0));
    expect(one['b.jpg']!.place, 'Park');
    expect(one['c.jpg']!.place, '');
    final two = await reload(p2.id);
    expect(two.latest.place, 'Diner');
    expect(two.trashedAt, isNotNull);
  });

  test('naming an unknown spot changes only that cluster', () async {
    final near = await person([met('a.jpg', '', north(0))]);
    final far = await person([met('b.jpg', '', north(5000), day: 2)]);
    final unknowns = PlaceBook.from(await repository.all())
        .groups
        .where((g) => g.label == 'unknown')
        .toList();
    final nearGroup = unknowns.firstWhere((g) => g.people.single.id == near.id);

    await PlaceRenamer(repository).rename(nearGroup, 'Home');

    expect((await reload(near.id)).latest.place, 'Home');
    expect((await reload(far.id)).latest.place, '');
  });

  test('a blank name is refused and changes nothing', () async {
    final p = await person([met('a.jpg', 'Cafe', north(0))]);

    await expectLater(
      PlaceRenamer(repository).rename(await groupLabelled('Cafe'), '  '),
      throwsArgumentError,
    );
    expect((await reload(p.id)).latest.place, 'Cafe');
  });

  test('a failed save surfaces; running it again finishes the job', () async {
    final p1 = await person([met('a.jpg', 'Cafe', north(0))]);
    final p2 = await person([met('b.jpg', 'Cafe', north(1))], trashed: true);
    final group = await groupLabelled('Cafe');
    final failing = _FailOnce(temp, p2.id);

    await expectLater(
      PlaceRenamer(failing).rename(group, 'Diner'),
      throwsA(isA<FileSystemException>()),
    );
    expect((await reload(p1.id)).latest.place, 'Diner');
    expect((await reload(p2.id)).latest.place, 'Cafe');

    await PlaceRenamer(failing).rename(group, 'Diner');
    expect((await reload(p2.id)).latest.place, 'Diner');
    expect((await reload(p1.id)).encounters, hasLength(1));
  });

  test('a person purged mid-rename is skipped; the rest still change',
      () async {
    final keep = await person([met('a.jpg', 'Cafe', north(0))]);
    final gone = await person([met('b.jpg', 'Cafe', north(1))], trashed: true);
    final group = await groupLabelled('Cafe');
    await repository.purge(gone.id);

    await PlaceRenamer(repository).rename(group, 'Diner');

    expect((await reload(keep.id)).latest.place, 'Diner');
    expect(await repository.trashed(), isEmpty);
  });

  test('naming one unknown spot of a person leaves their other unknown spot',
      () async {
    final p = await person([
      met('near.jpg', '', north(0), day: 2),
      met('far.jpg', '', north(5000), day: 1),
    ]);
    final unknowns = PlaceBook.from(await repository.all())
        .groups
        .where((g) => g.label == 'unknown')
        .toList();
    final nearGroup = unknowns.firstWhere(
      (g) => g.members.single.$2.photoFileName == 'near.jpg',
    );

    await PlaceRenamer(repository).rename(nearGroup, 'Home');

    final byPhoto = {
      for (final e in (await reload(p.id)).encounters) e.photoFileName: e.place
    };
    expect(byPhoto, {'near.jpg': 'Home', 'far.jpg': ''});
  });

  test('a spot named since the page loaded is not overwritten', () async {
    final p = await person([met('a.jpg', '', north(0))]);
    final group = await groupLabelled('unknown');
    await repository.save((await reload(p.id)).withField('place', 'Typed'));

    await PlaceRenamer(repository).rename(group, 'Home');

    expect((await reload(p.id)).latest.place, 'Typed');
  });
}
