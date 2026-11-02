import 'dart:convert';
import 'dart:io';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  Memory person(String id, {String? key}) => Memory(
        id: id,
        encounters: [
          Encounter(photoFileName: '$id.jpg', capturedAt: DateTime(2026)),
        ],
        contactKey: key,
      );

  group('model', () {
    test('the key round-trips, and is left out when there is none', () {
      final linked = person('a', key: '0r1-2B3C');
      expect(
        Memory.fromJson(
          jsonDecode(jsonEncode(linked)) as Map<String, dynamic>,
        ).contactKey,
        '0r1-2B3C',
      );
      expect(person('b').toJson().containsKey('contactKey'), isFalse);
    });

    test('a malformed key reads as no link, losing nothing else', () {
      for (final bad in <Object?>[42, '', '  ', true, <String>[]]) {
        final json = person('a').toJson()
          ..['contactKey'] = bad
          ..['fields'] = {'name': 'Ann'};
        final memory = Memory.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        );
        expect(memory.contactKey, isNull, reason: '$bad');
        expect(memory.displayName, 'Ann');
      }
    });

    test('every change keeps the link', () {
      final m = person('a', key: 'k');
      final changed = [
        m.withTrashedAt(DateTime(2026)),
        m.withScore(3, DateTime(2026)),
        m.withField('name', 'Ann'),
        m.withDetails(const []),
        m.withEncounters(m.encounters),
        m.withDetailScores(const []),
        m.withRelationshipsRetargeted('x', 'y'),
      ];
      for (final c in changed) {
        expect(c.contactKey, 'k');
      }
      expect(m.withContactKey(null).contactKey, isNull);
    });

    test('merge: the survivor keeps its own link, else adopts the other', () {
      expect(person('a', key: 'a1').merged(person('b', key: 'b1')).contactKey,
          'a1');
      expect(person('a').merged(person('b', key: 'b1')).contactKey, 'b1');
      final once = person('a').merged(person('b', key: 'b1'));
      expect(once.merged(person('b', key: 'b1')).contactKey, 'b1');
    });
  });

  group('repository', () {
    late Directory temp;
    late JsonFileMemoryRepository repository;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rememberem_contact_');
      repository = JsonFileMemoryRepository(temp);
    });
    tearDown(() => temp.delete(recursive: true));

    Future<Memory> add() =>
        repository.add(photoJpeg: [1], capturedAt: DateTime(2026));

    test('a stale editor save never undoes a link', () async {
      final m = await add();
      await repository.setContactKey(m.id, 'k');

      await repository.save(m.withField('name', 'Ann'));

      final saved = (await repository.all()).single;
      expect(saved.contactKey, 'k');
      expect(saved.displayName, 'Ann');
    });

    test('trash and restore keep the link; it can be removed', () async {
      final m = await add();
      await repository.setContactKey(m.id, 'k');
      await repository.trash(m.id, DateTime(2026, 2));
      await repository.restore(m.id);
      expect((await repository.all()).single.contactKey, 'k');

      await repository.setContactKey(m.id, null);
      expect((await repository.all()).single.contactKey, isNull);
    });

    test('merging on disk: an unlinked survivor adopts the other link',
        () async {
      final survivor = await add();
      final other = await add();
      await repository.setContactKey(other.id, 'theirs');

      final merged = await repository.merge(survivor.id, other.id);

      expect(merged.contactKey, 'theirs');
      expect((await repository.all()).single.contactKey, 'theirs');
    });

    test('a person that is gone cannot be linked', () async {
      expect(
        () => repository.setContactKey('nobody', 'k'),
        throwsA(isA<StateError>()),
      );
    });

    test('opening an old record writes nothing', () async {
      final m = await add();
      final file = File('${temp.path}/${m.id}.json');
      final before = file.readAsStringSync();

      await repository.all();

      expect(file.readAsStringSync(), before);
      expect(before.contains('contactKey'), isFalse);
    });
  });
}
