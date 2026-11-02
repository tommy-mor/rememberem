import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory person(String id, {String name = '', List<Detail> details = const []}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2026),
      fields: {'name': name},
      details: details,
    );

Detail detail(String id, String text, {int points = 0, DateTime? last}) =>
    Detail(
        id: id,
        text: text,
        at: DateTime.utc(2026),
        points: points,
        lastCorrectDate: last);

void main() {
  group('score on a detail', () {
    test('old details load with no score; a default adds no keys', () {
      final d = Detail.fromJson(
          {'id': 'd', 'text': 'Tall', 'at': '2026-01-01T00:00:00.000Z'});

      expect(d.points, 0);
      expect(d.lastCorrectDate, isNull);
      expect(d.toJson().keys, ['id', 'text', 'at']);
    });

    test('a score round-trips, follows text edits and re-dating', () {
      final d = detail('d', 'Tall', points: 3, last: DateTime(2026, 5, 6));
      final back =
          Detail.fromJson(jsonDecode(jsonEncode(d)) as Map<String, dynamic>);

      expect(back, d);
      expect(d.copyWith(text: 'Very tall').points, 3);
      expect(d.copyWith(at: DateTime.utc(2020)).lastCorrectDate,
          d.lastCorrectDate);
      expect(d == d.withScore(4, d.lastCorrectDate), isFalse);
    });

    test('merge keeps scores; the survivor wins a clash', () {
      final a = person('a', details: [detail('x', 'Tall', points: 2)]);
      final b = person('b', details: [
        detail('x', 'Tall', points: 9),
        detail('y', 'Kind', points: 5)
      ]);

      final merged = a.merged(b);

      expect(
          {for (final d in merged.details) d.id: d.points}, {'x': 2, 'y': 5});
    });
  });

  group('recordDetailAnswer', () {
    late Directory temp;
    late JsonFileMemoryRepository repository;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rememberem_dscore_');
      repository = JsonFileMemoryRepository(temp);
    });

    tearDown(() => temp.delete(recursive: true));

    Future<Memory> alex() async {
      final m =
          await repository.add(photoJpeg: [1], capturedAt: DateTime.utc(2026));
      final withDetails =
          m.withDetails([detail('d', 'Tall'), detail('e', 'Kind')]);
      await repository.save(withDetails);
      return withDetails;
    }

    Future<Detail> stored(String id) async =>
        (await repository.all()).single.details.firstWhere((d) => d.id == id);

    test('right adds a point and stamps; a miss resets; others untouched',
        () async {
      final m = await alex();
      final at = DateTime.utc(2026, 11, 1);

      await repository.recordDetailAnswer(m.id, 'd',
          correctFirstTry: true, at: at);
      expect((await stored('d')).points, 1);
      expect((await stored('d')).lastCorrectDate, at);

      await repository.recordDetailAnswer(m.id, 'd',
          correctFirstTry: false, at: DateTime.utc(2027));
      expect((await stored('d')).points, 0);
      expect((await stored('d')).lastCorrectDate, at);
      expect((await stored('e')).points, 0);
    });

    test('a stale editor save keeps the stored score, adds new details',
        () async {
      final stale = await alex();
      for (var i = 0; i < 4; i++) {
        await repository.recordDetailAnswer(stale.id, 'd',
            correctFirstTry: true, at: DateTime.utc(2026, 5));
      }

      await repository.save(stale.withDetails([
        stale.details.first.copyWith(text: 'Very tall'),
        stale.details.last,
        detail('n', 'New'),
      ]));

      expect((await stored('d')).points, 4);
      expect((await stored('d')).text, 'Very tall');
      expect((await stored('n')).points, 0);
    });

    test('a trashed person, gone person or missing detail is refused',
        () async {
      final m = await alex();

      await expectLater(
        repository.recordDetailAnswer(m.id, 'nope',
            correctFirstTry: true, at: DateTime.utc(2026)),
        throwsStateError,
      );
      await repository.trash(m.id, DateTime.utc(2026, 7));
      await expectLater(
        repository.recordDetailAnswer(m.id, 'd',
            correctFirstTry: true, at: DateTime.utc(2026)),
        throwsStateError,
      );
      await repository.purge(m.id);
      await expectLater(
        repository.recordDetailAnswer(m.id, 'd',
            correctFirstTry: true, at: DateTime.utc(2026)),
        throwsStateError,
      );
    });
  });

  group('DetailQuizPlanner', () {
    final now = DateTime.utc(2026, 11, 1);
    DetailQuizPlanner planner([int seed = 1]) =>
        DetailQuizPlanner(Random(seed), () => now);

    test('eligible pairs skip blank details', () {
      final people = [
        person('a', details: [detail('1', 'Tall'), detail('2', '  ')]),
        person('b'),
      ];

      expect(planner().eligible(people).map((p) => p.detail.id), ['1']);
    });

    test('needs four people and at least one detail', () {
      final three = [
        person('a', details: [detail('1', 'Tall')]),
        person('b'),
        person('c'),
      ];

      expect(planner().canPlay(three), isFalse);
      expect(planner().canPlay([...three, person('d')]), isTrue);
      expect(
          planner()
              .canPlay([person('a'), person('b'), person('c'), person('d')]),
          isFalse);
    });

    test('prefers weak details, and never the same detail twice in a row', () {
      final p = planner(5);
      final weak = (person: person('a'), detail: detail('w', 'Weak'));
      final strong = (
        person: person('b'),
        detail: detail('s', 'Strong', points: 50, last: now)
      );
      var weakPicks = 0;
      for (var i = 0; i < 50; i++) {
        if (p.pickNext([weak, strong]).detail.id == 'w') weakPicks++;
      }

      expect(weakPicks, greaterThan(40));
      for (var i = 0; i < 10; i++) {
        expect(
            p.pickNext([weak, strong], previousDetailId: 'w').detail.id, 's');
      }
    });

    test('choices are four different people, same names allowed', () {
      final people = [
        person('a', name: 'Sarah'),
        person('b', name: 'Sarah'),
        person('c', name: 'Tom'),
        person('d'),
        person('e', name: 'Bo'),
      ];

      final choices = planner(2).choicesFor(people.first, people);

      expect(choices, hasLength(4));
      expect(choices.map((m) => m.id).toSet(), hasLength(4));
      expect(choices.map((m) => m.id), contains('a'));
    });
  });
}
