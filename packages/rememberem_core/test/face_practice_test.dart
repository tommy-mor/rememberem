import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

Memory named(String id, String name, {int points = 0, DateTime? last}) =>
    Memory.captured(
      id: id,
      photoFileName: '$id.jpg',
      capturedAt: DateTime.utc(2026),
      fields: {'name': name},
    ).withScore(points, last);

void main() {
  group('score on the record', () {
    test('old records load with no score, and a default score adds no keys',
        () {
      final memory = Memory.fromJson({
        'id': 'a',
        'fields': {'name': 'Alex'},
        'encounters': [
          {'photo': 'a.jpg', 'capturedAt': '2026-01-01T00:00:00.000Z'},
        ],
      });

      expect(memory.points, 0);
      expect(memory.lastCorrectDate, isNull);
      final json = memory.toJson();
      expect(json.containsKey('points'), isFalse);
      expect(json.containsKey('lastCorrectDate'), isFalse);
    });

    test('a score round-trips in UTC', () {
      final memory =
          named('a', 'Alex', points: 3, last: DateTime(2026, 5, 6, 7));

      final back = Memory.fromJson(
          jsonDecode(jsonEncode(memory)) as Map<String, dynamic>);

      expect(back.points, 3);
      expect(back.lastCorrectDate!.isUtc, isTrue);
      expect(back.lastCorrectDate!.isAtSameMomentAs(DateTime(2026, 5, 6, 7)),
          isTrue);
    });

    test('edits, trash and merge keep the score; the survivor\'s wins', () {
      final alex = named('a', 'Alex', points: 3, last: DateTime.utc(2026, 2));
      final other = named('b', 'Al', points: 9, last: DateTime.utc(2026, 3));

      expect(alex.withField('name', 'Alexander').points, 3);
      expect(alex.withTrashedAt(DateTime.utc(2026)).points, 3);
      expect(alex.withEncounters(alex.encounters).points, 3);
      final merged = alex.merged(other);
      expect(merged.points, 3);
      expect(merged.lastCorrectDate, DateTime.utc(2026, 2));
      expect(jsonEncode(merged.merged(other)), jsonEncode(merged));
    });
  });

  group('recordAnswer', () {
    late Directory temp;
    late JsonFileMemoryRepository repository;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rememberem_score_');
      repository = JsonFileMemoryRepository(temp);
    });

    tearDown(() => temp.delete(recursive: true));

    Future<Memory> person() async {
      final memory =
          await repository.add(photoJpeg: [1], capturedAt: DateTime.utc(2026));
      final named = memory.withField('name', 'Alex');
      await repository.save(named);
      return named;
    }

    test('right first try adds a point and stamps the time; a miss resets',
        () async {
      final alex = await person();
      final at = DateTime.utc(2026, 11, 1, 12);

      await repository.recordAnswer(alex.id, correctFirstTry: true, at: at);
      await repository.recordAnswer(alex.id, correctFirstTry: true, at: at);
      var saved = (await repository.all()).single;
      expect(saved.points, 2);
      expect(saved.lastCorrectDate, at);

      await repository.recordAnswer(alex.id,
          correctFirstTry: false, at: DateTime.utc(2027));
      saved = (await repository.all()).single;
      expect(saved.points, 0);
      expect(saved.lastCorrectDate, at);
    });

    test('a stale save keeps the score; the score keeps the edit', () async {
      final stale = await person();
      await repository.recordAnswer(stale.id,
          correctFirstTry: true, at: DateTime.utc(2026, 5));

      await repository.save(stale.withField('name', 'Alex Davis'));

      var saved = (await repository.all()).single;
      expect(saved.points, 1);
      expect(saved.field(MemoryField.name), 'Alex Davis');

      await repository.recordAnswer(stale.id,
          correctFirstTry: true, at: DateTime.utc(2026, 6));
      saved = (await repository.all()).single;
      expect(saved.points, 2);
      expect(saved.field(MemoryField.name), 'Alex Davis');
    });

    test('answers for trashed or purged people are refused', () async {
      final alex = await person();
      await repository.trash(alex.id, DateTime.utc(2026, 7));

      await expectLater(
        repository.recordAnswer(alex.id,
            correctFirstTry: true, at: DateTime.utc(2026)),
        throwsStateError,
      );
      await repository.purge(alex.id);
      await expectLater(
        repository.recordAnswer(alex.id,
            correctFirstTry: true, at: DateTime.utc(2026)),
        throwsStateError,
      );
    });
  });

  group('FaceQuizPlanner', () {
    final now = DateTime.utc(2026, 11, 1);
    FaceQuizPlanner planner([int seed = 1]) =>
        FaceQuizPlanner(Random(seed), () => now);

    test('the weight favours few points and long-ago answers', () {
      final fresh = practiceWeight(0, null, now);
      final known = practiceWeight(5, now, now);

      expect(fresh, greaterThan(known));
      for (final w in [
        fresh,
        known,
        practiceWeight(1000, now.add(const Duration(days: 9)), now)
      ]) {
        expect(w > 0 && w.isFinite, isTrue);
      }
    });

    test('a weighted pick prefers the weak face', () {
      final weak = named('w', 'Weak');
      final strong = named('s', 'Strong', points: 50, last: now);
      var weakPicks = 0;
      final p = planner(7);
      for (var i = 0; i < 50; i++) {
        if (p.pickNext([weak, strong]).id == 'w') weakPicks++;
      }

      expect(weakPicks, greaterThan(40));
    });

    test('never the same person twice in a row when there is a choice', () {
      final people = [named('a', 'A'), named('b', 'B')];
      final p = planner();

      for (var i = 0; i < 20; i++) {
        expect(p.pickNext(people, previousId: 'a').id, 'b');
      }
      expect(p.pickNext([people.first], previousId: 'a').id, 'a');
    });

    test('blank names cannot be quizzed; shared names count once', () {
      final people = [
        named('1', 'Sarah'),
        named('2', 'Sarah '),
        named('3', '  '),
        named('4', 'Tom'),
        named('5', 'Ann'),
      ];
      final p = planner();

      expect(p.eligible(people).map((m) => m.id), ['1', '2', '4', '5']);
      expect(p.distinctNameCount(people), 3);
      expect(p.canPlay(people), isFalse);
      expect(p.canPlay([...people, named('6', 'Bo')]), isTrue);
    });

    test('choices are four different names including the answer', () {
      final people = [
        named('1', 'Sarah'),
        named('2', 'Sarah'),
        named('3', 'Tom'),
        named('4', 'Ann'),
        named('5', 'Bo'),
        named('6', 'Cy'),
      ];

      final choices = planner(3).choicesFor(people.first, people);

      expect(choices, hasLength(4));
      expect(choices.toSet(), hasLength(4));
      expect(choices.where((c) => c == 'Sarah'), hasLength(1));
    });
  });
}
