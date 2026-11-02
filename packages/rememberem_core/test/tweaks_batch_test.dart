import 'dart:io';
import 'dart:math';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Detail detail(
  String id, {
  String text = '',
  DetailKind type = DetailKind.fact,
  String? place,
  String? label,
  String? targetId,
  DateTime? eventDate,
}) =>
    Detail(
      id: id,
      text: text,
      at: DateTime.utc(2026),
      type: type,
      place: place,
      label: label,
      targetId: targetId,
      eventDate: eventDate,
    );

Memory person(String id, String name, [List<Detail> details = const []]) =>
    Memory(
      id: id,
      encounters: [
        Encounter(photoFileName: '$id.jpg', capturedAt: DateTime(2026)),
      ],
      fields: {'name': name},
      details: details,
    );

void main() {
  group('empty details', () {
    test('only a detail with nothing entered is empty', () {
      expect(detail('a').isEmpty, isTrue);
      expect(detail('a', text: '  ', place: ' ', label: '').isEmpty, isTrue);
      expect(detail('a', text: 'Tall').isEmpty, isFalse);
      expect(detail('a', type: DetailKind.happening, place: 'Park').isEmpty,
          isFalse);
      expect(detail('a', type: DetailKind.relationship, targetId: 'b').isEmpty,
          isFalse);
      expect(detail('a', type: DetailKind.relationship, label: 'boss').isEmpty,
          isFalse);
      expect(
        detail('a', type: DetailKind.anniversary, eventDate: DateTime(2010))
            .isEmpty,
        isFalse,
      );
    });

    test(
        'a relationship with no description is never asked, and does not '
        'stop a described one from being asked', () {
      final planner = DetailQuizPlanner(Random(1), () => DateTime(2026, 6));
      final people = [
        person('a', 'Ann'),
        person('b', 'Bo', [
          detail('1',
              type: DetailKind.relationship, label: 'boss', targetId: 'a'),
        ]),
        person('c', 'Cy', [
          detail('2',
              type: DetailKind.relationship,
              label: 'boss',
              targetId: 'a',
              text: 'Since 2020'),
        ]),
        person('d', 'Di'),
      ];
      expect(planner.eligible(people).map((p) => p.detail.id), ['2']);
    });
  });

  group('relationship index', () {
    final ann = person('a', 'Ann', [
      detail('1',
          type: DetailKind.relationship, label: 'brother', targetId: 'b'),
      detail('2',
          type: DetailKind.relationship, label: 'boss', targetId: 'gone'),
      detail('3', type: DetailKind.relationship, label: 'self', targetId: 'a'),
      detail('4', text: 'Tall'),
    ]);
    final bo = person('b', 'Bo');
    final cy = person('c', 'Cy', [
      detail('5',
          type: DetailKind.relationship, label: ' Friend ', targetId: 'a'),
      detail('6', type: DetailKind.relationship, label: 'aunt', targetId: 'b'),
    ]);
    final trashed = person('t', 'Ted', [
      detail('7', type: DetailKind.relationship, label: 'coach', targetId: 'a'),
    ]).withTrashedAt(DateTime(2026));

    test('own relationships first, then those pointing back', () {
      final links = RelationshipIndex.of(ann, [ann, bo, cy, trashed]);
      expect(
        [for (final l in links) (l.person.id, l.label, l.outgoing)],
        [('b', 'brother', true), ('c', 'Friend', false)],
      );
    });

    test('the current copy of the person wins over a stale one in the list',
        () {
      final edited = ann.withDetails([
        detail('9',
            type: DetailKind.relationship, label: 'cousin', targetId: 'c'),
      ]);
      final links = RelationshipIndex.of(edited, [ann, bo, cy]);
      expect(
        [for (final l in links) (l.person.id, l.label, l.outgoing)],
        [('c', 'cousin', true), ('c', 'Friend', false)],
      );
    });

    test('trashed or gone people and the person itself never show', () {
      final links = RelationshipIndex.of(ann, [ann, cy]);
      expect([for (final l in links) l.person.id], ['c']);
    });
  });

  group('repository', () {
    late Directory temp;
    late JsonFileMemoryRepository repository;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rememberem_tweaks_');
      repository = JsonFileMemoryRepository(temp);
    });
    tearDown(() => temp.delete(recursive: true));

    Future<Memory> add() =>
        repository.add(photoJpeg: [1, 2, 3], capturedAt: DateTime(2026));

    test('partial details of every kind survive a save and reload', () async {
      final m = await add();
      final partial = [
        detail('h', type: DetailKind.happening, place: 'Park'),
        detail('r', type: DetailKind.relationship, targetId: 'x'),
        detail('l', type: DetailKind.relationship, label: 'boss'),
        detail('n', type: DetailKind.anniversary, eventDate: DateTime(2010)),
      ];
      await repository.save(m.withDetails(partial));

      final loaded = (await repository.all()).single.details;
      expect([for (final d in loaded) d.id], ['h', 'r', 'l', 'n']);
      expect(loaded.every((d) => d.text.isEmpty && !d.isEmpty), isTrue);
      expect(loaded[3].eventDate, DateTime(2010));
    });

    test('replacing a photo keeps its name and touches nothing else', () async {
      final m = await add();
      final other = await add();
      final photo = repository.photoFile(m);
      final otherBytes = repository.photoFile(other).readAsBytesSync();

      await repository
          .replaceEncounterPhoto(m.id, m.latest.photoFileName, [9, 9]);

      expect(photo.readAsBytesSync(), [9, 9]);
      expect(repository.photoFile(other).readAsBytesSync(), otherBytes);
      expect(temp.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
      expect(
        (await repository.all())
            .firstWhere((x) => x.id == m.id)
            .latest
            .photoFileName,
        m.latest.photoFileName,
      );
    });

    test('a trashed, purged or changed person gets no photo written', () async {
      final m = await add();
      final name = m.latest.photoFileName;

      await expectLater(
        repository.replaceEncounterPhoto(m.id, 'other.jpg', [9]),
        throwsA(isA<StateError>()),
      );
      expect(File('${temp.path}/other.jpg').existsSync(), isFalse);

      await repository.trash(m.id, DateTime(2026, 2));
      await expectLater(
        repository.replaceEncounterPhoto(m.id, name, [9]),
        throwsA(isA<StateError>()),
      );
      expect(repository.photoFile(m).readAsBytesSync(), [1, 2, 3]);

      await repository.purge(m.id);
      await expectLater(
        repository.replaceEncounterPhoto(m.id, name, [9]),
        throwsA(isA<StateError>()),
      );
      expect(repository.photoFile(m).existsSync(), isFalse);
    });
  });
}
