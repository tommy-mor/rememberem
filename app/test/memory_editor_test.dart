import 'dart:convert';

import 'package:rememberem/src/memories/memory_editor.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';

void main() {
  final memory = Memory(
    id: 'a',
    photoFileName: 'a.jpg',
    capturedAt: DateTime.utc(2026, 11, 1),
  );

  test('saves once, shortly after a burst of changes', () {
    fakeAsync((async) {
      final repository = FakeMemoryRepository();
      final editor = MemoryEditor(repository, memory);

      editor.update('name', 'Alex');
      async.elapse(const Duration(milliseconds: 100));
      editor.update('name', 'Alex Davis');
      expect(repository.saves, isEmpty);

      async.elapse(const Duration(milliseconds: 500));
      expect(repository.saves.single.fields, {'name': 'Alex Davis'});
    });
  });

  test('flush saves pending changes immediately, and only once', () {
    fakeAsync((async) {
      final repository = FakeMemoryRepository();
      final editor = MemoryEditor(repository, memory);

      editor.update('place', 'Stake Center');
      editor.flush();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      editor.flush();
      async.flushMicrotasks();

      expect(repository.saves.single.fields, {'place': 'Stake Center'});
    });
  });

  group('details', () {
    test('a new detail is stamped with the clock and saved at once; '
        'later edits keep its time', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        var now = DateTime.utc(2026, 11, 1, 10, 0);
        final editor = MemoryEditor(repository, memory, clock: () => now);

        editor.updateDetail('d1', 'From');
        async.flushMicrotasks();
        expect(repository.saves.single.details.single.at, now);

        final first = now;
        now = DateTime.utc(2026, 11, 1, 10, 5);
        editor.updateDetail('d1', 'From Seattle');
        editor.updateDetail('d2', 'Choir');
        async.elapse(const Duration(seconds: 1));

        final saved = repository.saves.last.details;
        expect(saved.map((d) => d.text), ['From Seattle', 'Choir']);
        expect(saved[0].at, first);
        expect(saved[1].at, now);
      });
    });

    test('blank text never creates or saves a detail', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, memory);

        editor.updateDetail('d1', '   ');
        async.elapse(const Duration(seconds: 1));

        expect(repository.saves, isEmpty);
      });
    });

    test(
      'clearing a detail drops it from the save; retyping keeps its time',
      () {
        fakeAsync((async) {
          final repository = FakeMemoryRepository();
          var now = DateTime.utc(2026, 11, 1, 10);
          final editor = MemoryEditor(repository, memory, clock: () => now);
          editor.updateDetail('d1', 'Tall');
          final first = now;
          now = DateTime.utc(2026, 11, 2);

          editor.updateDetail('d1', '');
          async.elapse(const Duration(seconds: 1));
          expect(repository.saves.last.details, isEmpty);

          editor.updateDetail('d1', 'Very tall');
          async.elapse(const Duration(seconds: 1));
          expect(repository.saves.last.details.single.at, first);
        });
      },
    );

    test('editing only the name of a legacy record keeps its details once', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final legacy = Memory.fromJson({
          'id': 'old',
          'photo': 'old.jpg',
          'capturedAt': '2026-10-01T09:00:00.000Z',
          'fields': {'details': 'Likes hiking'},
        });
        final editor = MemoryEditor(repository, legacy);

        editor.update('name', 'Alex');
        editor.flush();
        async.flushMicrotasks();

        final json = repository.saves.single.toJson();
        expect((json['fields'] as Map).containsKey('details'), isFalse);
        expect(repository.saves.single.details.single.text, 'Likes hiking');
      });
    });

    test('clearing the only legacy detail stays cleared after reload', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final legacy = Memory.fromJson({
          'id': 'old',
          'photo': 'old.jpg',
          'capturedAt': '2026-10-01T09:00:00.000Z',
          'fields': {'details': 'Likes hiking'},
        });
        final editor = MemoryEditor(repository, legacy);

        editor.updateDetail('old-legacy', '');
        editor.flush();
        async.flushMicrotasks();

        final reloaded = Memory.fromJson(
          jsonDecode(jsonEncode(repository.saves.single))
              as Map<String, dynamic>,
        );
        expect(reloaded.details, isEmpty);
      });
    });
  });

  test('one failed save does not block later saves', () {
    fakeAsync((async) {
      final repository = FakeMemoryRepository()..failNextSave = true;
      final editor = MemoryEditor(repository, memory);

      editor.update('name', 'Alex');
      editor.flush().catchError((_) {});
      async.flushMicrotasks();
      editor.update('name', 'Alex Davis');
      editor.flush();
      async.flushMicrotasks();

      expect(repository.saves.single.field(MemoryField.name), 'Alex Davis');
    });
  });

  test('an unchanged value does not trigger a save', () {
    fakeAsync((async) {
      final repository = FakeMemoryRepository();
      final editor = MemoryEditor(repository, memory.withField('name', 'Alex'));

      editor.update('name', 'Alex');
      async.elapse(const Duration(seconds: 1));

      expect(repository.saves, isEmpty);
    });
  });
}
