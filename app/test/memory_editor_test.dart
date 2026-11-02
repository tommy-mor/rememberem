import 'dart:convert';

import 'package:rememberem/src/memories/memory_editor.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';

void main() {
  final memory = Memory.captured(
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

      expect(repository.saves.single.latest.place, 'Stake Center');
    });
  });

  group('details', () {
    test('an added detail saves at once; later edits keep its time and '
        'kind', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, memory);
        final at = DateTime.utc(2026, 11, 1, 10);

        editor.addDetail(
          Detail(id: 'd1', text: 'From', at: at, type: DetailKind.fact),
        );
        async.flushMicrotasks();
        expect(repository.saves.single.details.single.at, at);

        editor.updateDetail('d1', 'From Seattle');
        async.elapse(const Duration(seconds: 1));

        final saved = repository.saves.last.details.single;
        expect(
          [saved.text, saved.at, saved.kind],
          ['From Seattle', at, DetailKind.fact],
        );
      });
    });

    test('an added empty detail is kept for editing but never saved', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, memory);

        editor.addDetail(Detail(id: 'd1', text: '  ', at: DateTime.utc(2026)));
        editor.updateDetail('d2', 'nothing to update');
        async.elapse(const Duration(seconds: 1));

        expect(editor.memory.details.single.id, 'd1');
        expect(repository.saves.every((m) => m.details.isEmpty), isTrue);
      });
    });

    test('a relationship given only a person and a type is saved', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, memory);
        final blank = Detail(
          id: 'r',
          text: '',
          at: DateTime.utc(2026),
          type: DetailKind.relationship,
        );

        editor.addDetail(blank);
        editor.replaceDetail(blank.copyWith(targetId: () => 'b'));
        editor.replaceDetail(
          editor.memory.details.single.copyWith(label: 'brother'),
        );
        async.elapse(const Duration(seconds: 1));

        final saved = repository.saves.last.details.single;
        expect([saved.targetId, saved.label, saved.text], ['b', 'brother', '']);
      });
    });

    test('clearing a description drops it from the save; retyping brings '
        'it back with its time', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final at = DateTime.utc(2026, 11, 1, 10);
        final editor = MemoryEditor(repository, memory)
          ..addDetail(Detail(id: 'd1', text: 'Tall', at: at));

        editor.updateDetail('d1', '');
        async.elapse(const Duration(seconds: 1));
        expect(repository.saves.last.details, isEmpty);

        editor.updateDetail('d1', 'Very tall');
        async.elapse(const Duration(seconds: 1));
        expect(repository.saves.last.details.single.at, at);
      });
    });

    test('replacing a detail keeps its score and ignores a deleted one', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final scored = Detail(
          id: 'r',
          text: 'Kind',
          at: DateTime.utc(2026),
          type: DetailKind.relationship,
          label: 'boss',
          targetId: 'jill',
          points: 4,
        );
        final editor = MemoryEditor(repository, memory.withDetails([scored]));

        editor.replaceDetail(scored.copyWith(label: 'friend'));
        async.flushMicrotasks();
        expect(repository.saves.last.details.single.label, 'friend');
        expect(repository.saves.last.details.single.points, 4);

        editor.deleteDetail('r');
        editor.replaceDetail(scored.copyWith(label: 'mentor'));
        async.flushMicrotasks();
        expect(repository.saves.last.details, isEmpty);
      });
    });

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

  group('detail time, delete and restore', () {
    final at1 = DateTime.utc(2026, 11, 1, 10);
    final at2 = DateTime.utc(2026, 11, 1, 11);
    final withTwo = memory.withDetails([
      Detail(id: 'a', text: 'From Seattle', at: at1),
      Detail(id: 'b', text: 'Sings', at: at2),
    ]);

    test('re-dating saves at once and survives a later text edit', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, withTwo);
        final newAt = DateTime.utc(2020, 1, 2, 3, 4);

        editor.replaceDetail(withTwo.details.first.copyWith(at: newAt));
        async.flushMicrotasks();
        expect(repository.saves.last.details.first.at, newAt);

        editor.updateDetail('a', 'From Seattle, WA');
        async.elapse(const Duration(seconds: 1));
        final saved = repository.saves.last.details;
        expect(saved.map((d) => d.id), ['a', 'b']);
        expect(saved.first.at, newAt);
        expect(saved.first.text, 'From Seattle, WA');
      });
    });

    test('deleteDetail saves at once; a late edit cannot bring it back', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, withTwo);

        editor.updateDetail('a', 'typing...');
        editor.deleteDetail('a');
        async.flushMicrotasks();
        expect(repository.saves.last.details.map((d) => d.id), ['b']);

        editor.updateDetail('a', 'late dictation');
        async.elapse(const Duration(seconds: 1));
        expect(repository.saves.last.details.map((d) => d.id), ['b']);
      });
    });

    test('restoreDetail puts it back in place and it is editable again', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, withTwo);
        final deleted = withTwo.details.first;

        editor.deleteDetail('a');
        editor.restoreDetail(deleted, 0);
        editor.updateDetail('a', 'new');
        async.elapse(const Duration(seconds: 1));

        final saved = repository.saves.last.details;
        expect(saved.map((d) => d.id), ['a', 'b']);
        expect(saved.first.text, 'new');
        expect(saved.first.at, at1);
      });
    });

    test('a delete whose save failed is retried by the next flush', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository()..failNextSave = true;
        final editor = MemoryEditor(repository, withTwo);

        editor.deleteDetail('a');
        async.flushMicrotasks();
        expect(repository.saves, isEmpty);

        editor.flush();
        async.flushMicrotasks();
        expect(repository.saves.last.details.map((d) => d.id), ['b']);
      });
    });

    test('a failed save on delete raises no unhandled error', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository()..failNextSave = true;
        final editor = MemoryEditor(repository, withTwo);

        editor.deleteDetail('a');
        async.flushMicrotasks();
        editor.replaceDetail(withTwo.details.last.copyWith(at: at1));
        async.flushMicrotasks();

        expect(repository.saves.last.details.single.at, at1);
      });
    });

    test('a legacy detail can be changed and deleted for good', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final legacy = Memory.fromJson({
          'id': 'old',
          'photo': 'old.jpg',
          'capturedAt': '2026-10-01T09:00:00.000Z',
          'fields': {'details': 'Likes hiking'},
        });
        final editor = MemoryEditor(repository, legacy);

        editor.replaceDetail(legacy.details.single.copyWith(at: at2));
        async.flushMicrotasks();
        expect(repository.saves.last.details.single.at, at2);

        editor.deleteDetail('old-legacy');
        async.flushMicrotasks();
        final reloaded = Memory.fromJson(
          jsonDecode(jsonEncode(repository.saves.last)) as Map<String, dynamic>,
        );
        expect(reloaded.details, isEmpty);
      });
    });
  });

  test('a failed debounced save raises no unhandled error', () {
    fakeAsync((async) {
      final repository = FakeMemoryRepository()..failNextSave = true;
      final editor = MemoryEditor(repository, memory);

      editor.update('name', 'Alex');
      async.elapse(const Duration(seconds: 1)); // would throw if unhandled

      expect(repository.saves, isEmpty);
      editor.flush();
      async.flushMicrotasks();
      expect(repository.saves.single.field(MemoryField.name), 'Alex');
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
