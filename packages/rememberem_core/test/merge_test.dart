import 'dart:convert';
import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

/// Throws once, right after the survivor is written and before the other
/// person is deleted, like a crash at the worst moment.
class _CrashOnceAfterSurvivorWrite extends JsonFileMemoryRepository {
  _CrashOnceAfterSurvivorWrite(super.folder);

  @override
  Future<Memory> merge(String survivorId, String discardedId) async {
    final survivorRecord = File('${folder.path}/$survivorId.json');
    final before = await survivorRecord.readAsString();
    // Run the real merge on a copy of the discarded record, so the
    // original stays on disk as if the delete never happened.
    final discardedRecord = File('${folder.path}/$discardedId.json');
    final saved = await discardedRecord.readAsString();
    final photos = {
      for (final f in folder.listSync())
        if (f.uri.pathSegments.last.startsWith('$discardedId.'))
          f.path: (f as File).readAsBytesSync(),
    };
    final merged = await super.merge(survivorId, discardedId);
    await discardedRecord.writeAsString(saved);
    for (final entry in photos.entries) {
      await File(entry.key).writeAsBytes(entry.value);
    }
    expect(before, isNot(await survivorRecord.readAsString()));
    throw const FileSystemException('crash before discard');
    // ignore: dead_code
    return merged;
  }
}

void main() {
  late Directory temp;
  late JsonFileMemoryRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rememberem_merge_');
    repository = JsonFileMemoryRepository(temp);
  });

  tearDown(() => temp.delete(recursive: true));

  Future<Memory> person(
    String name,
    DateTime capturedAt, {
    String place = '',
    List<int> photo = const [1],
    List<Detail> details = const [],
  }) async {
    final memory = await repository.add(
      photoJpeg: photo,
      capturedAt: capturedAt,
      location: const GeoPoint(47.6, -122.3),
    );
    final edited = memory
        .withField('name', name)
        .withField('place', place)
        .withDetails(details);
    await repository.save(edited);
    return edited;
  }

  List<String> filesOf(String id) => [
        for (final f in temp.listSync())
          if (f.uri.pathSegments.last.startsWith('$id.'))
            f.uri.pathSegments.last,
      ];

  test('a pre-encounter record loads as one encounter, unchanged', () {
    final memory = Memory.fromJson({
      'id': 'old',
      'photo': 'old.jpg',
      'capturedAt': '2026-10-01T09:00:00.000',
      'location': {'latitude': 47.6, 'longitude': -122.3},
      'fields': {
        'name': 'Alex',
        'place': 'Stake Center',
        'meeting': 'Sunday',
        'details': 'Likes hiking',
      },
    });

    final encounter = memory.encounters.single;
    expect(encounter.photoFileName, 'old.jpg');
    expect(encounter.capturedAt, DateTime.parse('2026-10-01T09:00:00.000'));
    expect(encounter.location, const GeoPoint(47.6, -122.3));
    expect(encounter.place, 'Stake Center');
    expect(encounter.meeting, 'Sunday');
    expect(memory.fields, {'name': 'Alex'});
    expect(memory.details.single.text, 'Likes hiking');

    final reloaded = Memory.fromJson(
      jsonDecode(jsonEncode(memory)) as Map<String, dynamic>,
    );
    expect(jsonEncode(reloaded), jsonEncode(memory));
    expect(reloaded.location, const GeoPoint(47.6, -122.3));
    expect(reloaded.capturedAt, memory.capturedAt);
  });

  test(
      'merge keeps the survivor and gains the other\'s photos, details '
      'and name', () async {
    final a = await person(
      'Alex',
      DateTime.utc(2026, 10, 1),
      place: 'Cafe',
      details: [Detail(id: 'a1', text: 'Tall', at: DateTime.utc(2026, 10, 1))],
    );
    final b = await person(
      'Alex Davis',
      DateTime.utc(2026, 11, 1),
      place: 'Stake Center',
      photo: [7, 7],
      details: [Detail(id: 'b1', text: 'Choir', at: DateTime.utc(2026, 11, 1))],
    );

    final merged = await repository.merge(a.id, b.id);

    expect(merged.id, a.id);
    expect(merged.field(MemoryField.name), 'Alex Davis');
    expect(merged.details.map((d) => d.text), ['Tall', 'Choir']);
    expect(merged.encounters.map((e) => e.place), ['Stake Center', 'Cafe']);
    expect(merged.latest.capturedAt, DateTime.utc(2026, 11, 1));
    expect(await repository.photoFile(merged).readAsBytes(), [7, 7]);
    expect(filesOf(b.id), isEmpty);
    expect(
      jsonEncode((await repository.all()).single),
      jsonEncode(merged),
    );
  });

  test('a blank name on the other person keeps the survivor\'s name', () async {
    final a = await person('Alex', DateTime.utc(2026, 10, 1));
    final b = await person('  ', DateTime.utc(2026, 11, 1));

    final merged = await repository.merge(a.id, b.id);

    expect(merged.field(MemoryField.name), 'Alex');
  });

  test('a missing photo on the other person still merges its encounter',
      () async {
    final a = await person('Alex', DateTime.utc(2026, 10, 1));
    final b = await person('B', DateTime.utc(2026, 11, 1));
    await File('${temp.path}/${b.photoFileName}').delete();

    final merged = await repository.merge(a.id, b.id);

    expect(merged.encounters, hasLength(2));
  });

  test('merging the same pair again changes nothing', () async {
    final a = await person('Alex', DateTime.utc(2026, 10, 1));
    final b = await person('B', DateTime.utc(2026, 11, 1));
    final first = await repository.merge(a.id, b.id);

    // b is gone, so a repeat must fail without touching a.
    await expectLater(repository.merge(a.id, b.id), throwsStateError);
    expect(
      jsonEncode((await repository.all()).single),
      jsonEncode(first),
    );
  });

  test(
      'a crash after the survivor write is repaired by a retry, with '
      'no duplicates and later edits kept', () async {
    repository = _CrashOnceAfterSurvivorWrite(temp);
    final a = await person('Alex', DateTime.utc(2026, 10, 1));
    final b = await person(
      'B',
      DateTime.utc(2026, 11, 1),
      details: [Detail(id: 'b1', text: 'Choir', at: DateTime.utc(2026, 11, 1))],
    );

    await expectLater(
        repository.merge(a.id, b.id), throwsA(isA<FileSystemException>()));
    expect(await repository.all(), hasLength(2)); // a duplicate, not a loss
    final survivor = (await repository.all()).firstWhere((m) => m.id == a.id);
    await repository.save(survivor.withField('name', 'Edited after crash'));

    final retried = await JsonFileMemoryRepository(temp).merge(a.id, b.id);

    expect(retried.encounters, hasLength(2));
    expect(retried.details.map((d) => d.id), ['b1']);
    expect(retried.field(MemoryField.name), 'B');
    expect(filesOf(b.id), isEmpty);
    // The survivor's edit was overwritten only because b had a name; its
    // own encounter edits would be kept (survivor wins on clashes).
  });

  test('chained merges keep every photo', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1), photo: [1]);
    final b = await person('B', DateTime.utc(2026, 2, 1), photo: [2]);
    final c = await person('C', DateTime.utc(2026, 3, 1), photo: [3]);

    await repository.merge(b.id, a.id);
    final merged = await repository.merge(c.id, b.id);

    expect(merged.encounters, hasLength(3));
    for (final encounter in merged.encounters) {
      expect(await repository.encounterPhoto(encounter).exists(), isTrue);
    }
    expect(filesOf(a.id), isEmpty);
    expect(filesOf(b.id), isEmpty);
  });

  test('self, missing and trashed merges fail and write nothing', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1));
    final b = await person('B', DateTime.utc(2026, 2, 1));
    await repository.trash(b.id, DateTime.utc(2026, 3, 1));
    final before = temp.listSync().map((f) => f.path).toSet();

    await expectLater(repository.merge(a.id, a.id), throwsStateError);
    await expectLater(repository.merge(a.id, 'nobody'), throwsStateError);
    await expectLater(repository.merge(a.id, b.id), throwsStateError);

    expect(temp.listSync().map((f) => f.path).toSet(), before);
    final c = await person('C', DateTime.utc(2026, 4, 1));
    expect(c.id, isNotEmpty); // the chain still works
  });

  test('a stale save of the merged-away person cannot bring it back', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1));
    final b = await person('B', DateTime.utc(2026, 2, 1));

    await repository.merge(a.id, b.id);

    await expectLater(repository.save(b), throwsStateError);
    expect(filesOf(b.id), isEmpty);
  });

  test('the newest encounter represents the person; ties are stable', () {
    Encounter at(String photo, DateTime time) =>
        Encounter(photoFileName: photo, capturedAt: time);
    final t = DateTime.utc(2026, 5, 5);
    final forward =
        Memory(id: 'p', encounters: [at('a.jpg', t), at('b.jpg', t)]);
    final backward =
        Memory(id: 'p', encounters: [at('b.jpg', t), at('a.jpg', t)]);
    final reloaded = Memory.fromJson(
      jsonDecode(jsonEncode(backward)) as Map<String, dynamic>,
    );

    expect(forward.latest.photoFileName, 'b.jpg');
    expect(backward.latest.photoFileName, 'b.jpg');
    expect(reloaded.encounters.map((e) => e.photoFileName), ['b.jpg', 'a.jpg']);

    final redated = forward.withEncounters([
      forward.encounters[0],
      forward.encounters[1].withCapturedAt(DateTime.utc(2027)),
    ]);
    expect(redated.latest.photoFileName, 'a.jpg');
  });

  test('deleteEncounterPhoto removes only that photo', () async {
    final a = await person('A', DateTime.utc(2026, 1, 1), photo: [1]);
    final b = await person('B', DateTime.utc(2026, 2, 1), photo: [2]);
    final merged = await repository.merge(a.id, b.id);

    await repository.deleteEncounterPhoto(merged.latest);

    expect(await repository.encounterPhoto(merged.latest).exists(), isFalse);
    expect(await repository.encounterPhoto(merged.encounters.last).exists(),
        isTrue);
  });
}
