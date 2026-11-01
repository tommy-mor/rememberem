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

  test('an unchanged value does not trigger a save', () {
    fakeAsync((async) {
      final repository = FakeMemoryRepository();
      final editor =
          MemoryEditor(repository, memory.withField('name', 'Alex'));

      editor.update('name', 'Alex');
      async.elapse(const Duration(seconds: 1));

      expect(repository.saves, isEmpty);
    });
  });
}
