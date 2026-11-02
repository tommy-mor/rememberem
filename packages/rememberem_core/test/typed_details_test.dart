import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Detail fact(String id, String text) =>
    Detail(id: id, text: text, at: DateTime.utc(2026), type: DetailKind.fact);

Detail rel(String id, String label, String target, {String text = 'Kind'}) =>
    Detail(
      id: id,
      text: text,
      at: DateTime.utc(2026),
      type: DetailKind.relationship,
      label: label,
      targetId: target,
    );

void main() {
  group('storage', () {
    test('an untyped detail reads as a fact and writes no type, unchanged', () {
      final json = {
        'id': 'd',
        'text': 'Sings',
        'at': '2026-01-01T00:00:00.000Z',
        'points': 3,
      };
      final detail = Detail.fromJson(json);
      expect(detail.kind, DetailKind.fact);
      expect(detail.points, 3);
      expect(detail.toJson(), json);
      expect(detail.copyWith(text: 'Sings').toJson(), json);
    });

    test('every kind round-trips; new facts say they are facts', () {
      final details = [
        fact('f', 'Loves jazz'),
        Detail(
          id: 'h',
          text: 'Picnic',
          at: DateTime.utc(2026, 5, 1, 12),
          type: DetailKind.happening,
          place: 'Park',
        ),
        rel('r', 'boss', 'jill'),
        Detail(
          id: 'a',
          text: 'Big party',
          at: DateTime.utc(2026),
          type: DetailKind.anniversary,
          label: 'wedding',
          eventDate: DateTime(2010, 6, 3),
        ),
      ];
      for (final d in details) {
        final again = Detail.fromJson(
          jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
        );
        expect(again, d);
      }
      expect(details.first.toJson()['type'], 'fact');
      expect(details.last.toJson()['eventDate'], '2010-06-03');
    });

    test('bad data in the new keys loses only that value', () {
      final detail = Detail.fromJson({
        'id': 'd',
        'text': 'Kept',
        'at': '2026-01-01T00:00:00.000Z',
        'type': 'spaceship',
        'place': 7,
        'targetId': ['x'],
        'label': false,
        'eventDate': '2026-02-30',
        'points': 2,
      });
      expect(detail.kind, DetailKind.fact);
      expect(
        [detail.place, detail.targetId, detail.label, detail.eventDate],
        everyElement(isNull),
      );
      expect([detail.text, detail.points], ['Kept', 2]);
      expect(
        Detail.fromJson({
          'id': 'd',
          'text': 't',
          'at': '2026-01-01T00:00:00.000Z',
          'type': 42,
        }).kind,
        DetailKind.fact,
      );
    });

    test('a scored detail keeps its score through any edit', () {
      final d = rel('r', 'boss', 'jill').withScore(4, DateTime.utc(2026, 2));
      final edited = d
          .copyWith(text: 'New', label: 'mentor', targetId: () => 'jane')
          .copyWith(at: DateTime.utc(2027));
      expect(
          [edited.points, edited.lastCorrectDate], [4, DateTime.utc(2026, 2)]);
      expect(edited.kind, DetailKind.relationship);
    });
  });

  group('prompts', () {
    String? names(String id) => {'jill': 'Jill'}[id];

    test('each kind reads as specified', () {
      expect(DetailPrompt(fact('f', 'Loves jazz'), names).full, 'Loves jazz');
      expect(
        DetailPrompt(rel('r', 'boss', 'jill'), names).prefix,
        'My boss is Jill',
      );
      expect(
        DetailPrompt(rel('r', 'boss', 'gone'), names).prefix,
        'My boss is someone removed',
      );
      final anniversary = Detail(
        id: 'a',
        text: 'Big party',
        at: DateTime.utc(2026),
        type: DetailKind.anniversary,
        label: 'wedding',
        eventDate: DateTime(2010, 6, 3),
      );
      expect(
        DetailPrompt(anniversary, names).full,
        'Wedding, 3 Jun 2010: Big party',
      );
      final happening = Detail(
        id: 'h',
        text: 'Picnic',
        at: DateTime(2026, 5, 1, 12),
        type: DetailKind.happening,
        place: 'Park',
      );
      expect(DetailPrompt(happening, names).prefix, '1 May 2026, Park');
      expect(DetailPrompt(happening, names).caption, 'Happening');
    });
  });

  group('catalog', () {
    Memory owner(String id, List<Detail> details) => Memory(
          id: id,
          encounters: [
            Encounter(photoFileName: '$id.jpg', capturedAt: DateTime(2026)),
          ],
          details: details,
        );

    test('defaults first, then custom types in use, folded by case', () {
      final people = [
        owner('a', [rel('1', 'Mentor ', 'b'), rel('2', 'boss', 'b')]),
        owner('b', [rel('3', 'mentor', 'a'), rel('4', 'Neighbor', 'a')]),
      ];
      expect(
        DetailTypeCatalog.labels(DetailKind.relationship, people),
        [...DetailTypeCatalog.relationshipDefaults, 'Mentor', 'Neighbor'],
      );
      expect(
        DetailTypeCatalog.labels(DetailKind.relationship, [owner('a', [])]),
        DetailTypeCatalog.relationshipDefaults,
      );
      expect(
        DetailTypeCatalog.labels(DetailKind.anniversary, people),
        DetailTypeCatalog.anniversaryDefaults,
      );
    });
  });

  group('repository', () {
    late Directory temp;
    late JsonFileMemoryRepository repository;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rememberem_typed_');
      repository = JsonFileMemoryRepository(temp);
    });
    tearDown(() => temp.delete(recursive: true));

    Future<Memory> person(String name,
        [List<Detail> details = const []]) async {
      final m = await repository.add(
        photoJpeg: [1],
        capturedAt: DateTime(2026, 1, 1 + (await repository.all()).length),
      );
      final named = m.withField('name', name).withDetails(details);
      await repository.save(named);
      return named;
    }

    Future<Memory> reload(String id) async => [
          ...await repository.all(),
          ...await repository.trashed(),
        ].firstWhere((m) => m.id == id);

    test('renaming, trashing and restoring the target keeps the link',
        () async {
      final jill = await person('Jill');
      final fred = await person('Fred', [rel('r', 'boss', jill.id)]);

      await repository.save(jill.withField('name', 'Jillian'));
      await repository.trash(jill.id, DateTime(2026, 3));
      await repository.restore(jill.id);

      expect((await reload(fred.id)).details.single.targetId, jill.id);
    });

    test('purging the target clears the link everywhere, keeping the rest',
        () async {
      final jill = await person('Jill');
      final fred = await person('Fred', [rel('r', 'boss', jill.id)]);
      final ann = await person('Ann', [rel('s', 'friend', jill.id)]);
      await repository.trash(ann.id, DateTime(2026, 3));
      await repository.trash(jill.id, DateTime(2026, 3));
      // A corrupt record must not block the purge.
      await File('${temp.path}/broken.json').writeAsString('{oops');

      await repository.purge(jill.id);
      await File('${temp.path}/broken.json').delete();

      for (final id in [fred.id, ann.id]) {
        final d = (await reload(id)).details.single;
        expect(d.targetId, isNull);
        expect([d.label, d.text], isNotEmpty);
      }
    });

    test('merging moves links to the survivor and drops self-links', () async {
      final jane = await person('Jane');
      final jill = await person('Jill', [rel('x', 'friend', jane.id)]);
      final fred = await person('Fred', [rel('r', 'boss', jill.id)]);

      final merged = await repository.merge(jane.id, jill.id);

      expect((await reload(fred.id)).details.single.targetId, jane.id);
      expect(merged.details.where((d) => d.targetId == jane.id), isEmpty);
    });

    test('only records that change are rewritten', () async {
      final jill = await person('Jill');
      final bystander = await person('Bo', [fact('f', 'Tall')]);
      final file = File('${temp.path}/${bystander.id}.json');
      final before = file.lastModifiedSync();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repository.trash(jill.id, DateTime(2026, 3));

      await repository.purge(jill.id);

      expect(file.lastModifiedSync(), before);
    });
  });

  group('details quiz', () {
    Memory owner(String id, String name, List<Detail> details) => Memory(
          id: id,
          encounters: [
            Encounter(photoFileName: '$id.jpg', capturedAt: DateTime(2026)),
          ],
          fields: {'name': name},
          details: details,
        );
    final planner = DetailQuizPlanner(Random(1), () => DateTime(2026, 6));

    test('a detail another person also has is never asked', () {
      final people = [
        owner('a', 'Ann', [fact('1', 'Loves jazz'), fact('2', 'Tall')]),
        owner('b', 'Bo', [fact('3', 'loves jazz ')]),
        owner('c', 'Cy', [rel('4', 'boss', 'a'), rel('5', 'Boss', 'a')]),
        owner('d', 'Di', [rel('6', 'boss', 'a')]),
      ];
      expect(planner.eligible(people).map((p) => p.detail.id), ['2']);
    });

    test('two different people with the same name are one answer', () {
      final people = [
        owner('j1', 'Jill', []),
        owner('j2', 'Jill', []),
        owner('a', 'Ann', [rel('1', 'boss', 'j1')]),
        owner('b', 'Bo', [rel('2', 'boss', 'j2')]),
      ];
      expect(planner.eligible(people), isEmpty);
    });

    test('incomplete or unresolved details are never asked', () {
      final people = [
        owner('a', 'Ann', [
          rel('1', 'boss', 'gone'),
          rel('2', 'boss', 'a'),
          Detail(
            id: '3',
            text: 'Party',
            at: DateTime.utc(2026),
            type: DetailKind.anniversary,
            label: 'wedding',
          ),
        ]),
        owner('b', 'Bo', []),
        owner('c', 'Cy', []),
        owner('d', 'Di', []),
      ];
      expect(planner.eligible(people), isEmpty);
      expect(planner.canPlay(people), isFalse);
      expect(
        ReminderTarget.resolve(people, PracticeGame.details),
        isNot(PracticeGame.details),
      );
    });

    test(
        'with random data every eligible detail has exactly one owner '
        'reading it that way', () {
      final rng = Random(7);
      const texts = ['Kind', 'Tall', 'Loves jazz'];
      const labels = ['boss', 'friend', 'Boss'];
      for (var round = 0; round < 50; round++) {
        final people = [
          for (var p = 0; p < 6; p++)
            owner('p$p', ['Ann', 'Bo', 'Jill', 'Jill', 'Cy', ''][p], [
              for (var i = 0; i < 3; i++)
                if (rng.nextBool())
                  fact('p$p-f$i', texts[rng.nextInt(3)])
                else
                  rel(
                    'p$p-r$i',
                    labels[rng.nextInt(3)],
                    'p${rng.nextInt(6)}',
                    text: texts[rng.nextInt(3)],
                  ),
            ]),
        ];
        final prompt = DetailQuizPlanner.promptFor(people);
        for (final pair in planner.eligible(people)) {
          final key = prompt(pair.detail).equivalenceKey;
          final readers = {
            for (final m in people)
              for (final d in m.details)
                if (prompt(d).equivalenceKey == key) m.id,
          };
          expect(readers, {pair.person.id});
        }
      }
    });
  });
}
