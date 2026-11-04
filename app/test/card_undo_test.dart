import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/edit_history.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_editor.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  final memory = Memory.captured(
    id: 'a',
    photoFileName: 'a.jpg',
    capturedAt: DateTime.utc(2026, 11, 1),
  );
  Detail fact(String id, String text) =>
      Detail(id: id, text: text, at: DateTime.utc(2026, 11, 1));
  CardState state(String name) =>
      (fields: {'name': name}, details: const [], photo: null);

  group('EditHistory', () {
    test('undo and redo walk the steps; a new change ends Redo', () {
      final h = EditHistory();
      h.record(state('A'));
      h.record(state('B'));
      expect(h.undo(state('C'))!.fields['name'], 'B');
      expect(h.undo(state('B'))!.fields['name'], 'A');
      expect(h.canUndo, isFalse);
      expect(h.redo(state('A'))!.fields['name'], 'B');
      expect(h.canRedo, isTrue);

      h.record(state('B'));
      expect(h.canRedo, isFalse);
    });

    test('a run of typing in one field is one step', () {
      final h = EditHistory();
      h.record(state(''), key: 'field:name');
      h.record(state('A'), key: 'field:name');
      h.record(state('Al'), key: 'field:name');
      expect(h.undo(state('Ali'))!.fields['name'], '');
      expect(h.canUndo, isFalse);
    });

    test('another field, or an undo, starts a new run', () {
      final h = EditHistory();
      h.record(state(''), key: 'field:name');
      h.record(state('A'), key: 'detail:x');
      h.record(state('A'), key: 'field:name');
      expect(h.undo(state('Ab'))!.fields['name'], 'A');
      h.record(state('A'), key: 'field:name');
      expect(h.undo(state('Ac')), isNotNull);
      expect(h.undo(state('A')), isNotNull);
      expect(h.canUndo, isTrue); // the first run is still there
    });
  });

  group('MemoryEditor undo', () {
    test('undoes typed text in one step, redoes it, and saves each', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(repository, memory);
        editor.update('name', 'A');
        editor.update('name', 'Ann');
        editor.update('place', 'Cafe');

        editor.undo();
        expect(editor.memory.field(MemoryField.place), '');
        expect(editor.memory.field(MemoryField.name), 'Ann');
        editor.undo();
        expect(editor.memory.field(MemoryField.name), '');
        async.flushMicrotasks();
        expect(repository.saves.last.field(MemoryField.name), '');

        editor.redo();
        async.flushMicrotasks();
        expect(repository.saves.last.field(MemoryField.name), 'Ann');
        expect(editor.canRedo, isTrue);
      });
    });

    test('undoes an added detail, a delete, a type change and a '
        'description', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(
          repository,
          memory.withDetails([fact('x', 'Tall')]),
        );
        editor.addDetail(fact('y', ''));
        editor.updateDetail('y', 'Kind');
        editor.replaceDetail(
          editor.memory.details.last.copyWith(label: 'note'),
        );
        editor.deleteDetail('x');

        editor.undo(); // delete
        expect(editor.memory.details.map((d) => d.id), ['x', 'y']);
        editor.undo(); // type
        expect(editor.memory.details.last.label, isNull);
        editor.undo(); // description
        expect(editor.memory.details.last.text, '');
        editor.undo(); // add
        expect(editor.memory.details.map((d) => d.id), ['x']);
        expect(editor.canUndo, isFalse);
      });
    });

    test('a detail back from Undo takes edits again; one undone away '
        'ignores late ones', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        final editor = MemoryEditor(
          repository,
          memory.withDetails([fact('x', 'Tall')]),
        );
        editor.deleteDetail('x');
        editor.undo();
        editor.updateDetail('x', 'Very tall');
        expect(editor.memory.details.single.text, 'Very tall');

        editor.addDetail(fact('y', ''));
        editor.undo();
        editor.updateDetail('y', 'late words');
        expect(editor.memory.details.map((d) => d.id), ['x']);
      });
    });

    test('undo keeps a practice score earned meanwhile', () {
      fakeAsync((async) {
        final repository = FakeMemoryRepository();
        repository.stored[memory.id] = memory.withDetails([fact('x', 'Tall')]);
        final editor = MemoryEditor(repository, repository.stored[memory.id]!);
        editor.updateDetail('x', 'Short');
        async.elapse(const Duration(seconds: 1));
        repository.recordDetailAnswer(
          memory.id,
          'x',
          correctFirstTry: true,
          at: DateTime.utc(2026, 11, 2),
        );
        async.flushMicrotasks();

        editor.undo();
        async.flushMicrotasks();

        final saved = repository.stored[memory.id]!.details.single;
        expect(saved.text, 'Tall');
        expect(saved.points, 1);
      });
    });

    test('a crop is one step: Undo writes the old photo back, Redo the '
        'crop, and earlier steps leave the photo alone', () async {
      final repository = FakeMemoryRepository();
      repository.stored[memory.id] = memory;
      final editor = MemoryEditor(repository, memory);
      editor.update('name', 'Ann');
      await editor.cropPhoto('a.jpg', before: [1], after: [2]);
      expect(repository.replacedPhotos.single.$3, [2]);
      expect(editor.canUndo, isTrue);

      await editor.undo();
      expect(repository.replacedPhotos.last.$3, [1]);
      expect(editor.memory.field(MemoryField.name), 'Ann');

      expect(editor.undo(), isNull); // the name: the photo stays
      expect(editor.memory.field(MemoryField.name), '');
      expect(repository.replacedPhotos, hasLength(2));

      expect(editor.redo(), isNull);
      await editor.redo();
      expect(repository.replacedPhotos.last.$3, [2]);
      expect(editor.canRedo, isFalse);
    });

    test('after the history is cleared, Undo never puts back a photo '
        'from before', () async {
      final repository = FakeMemoryRepository();
      repository.stored[memory.id] = memory;
      final editor = MemoryEditor(repository, memory);
      await editor.cropPhoto('a.jpg', before: [1], after: [2]);
      editor.clearHistory();
      editor.update('name', 'Ann');
      await editor.cropPhoto('a.jpg', before: [9], after: [3]);

      await editor.undo(); // the second crop
      expect(editor.undo(), isNull); // the name
      expect(
        [for (final p in repository.replacedPhotos) p.$3],
        [
          [2],
          [3],
          [9],
        ],
      );
    });

    test('a photo that cannot be written back is still the one Undo and '
        'Redo know', () async {
      final repository = FakeMemoryRepository();
      repository.stored[memory.id] = memory;
      final editor = MemoryEditor(repository, memory);
      await editor.cropPhoto('a.jpg', before: [1], after: [2]);

      repository.failNextReplace = true;
      await expectLater(editor.undo(), throwsA(isA<FileSystemException>()));
      // The file still holds the crop, so Redo has nothing to write.
      expect(editor.redo(), isNull);
      expect(repository.replacedPhotos, hasLength(1));
    });

    test('listeners hear when Undo becomes possible and when the history '
        'is cleared', () {
      final editor = MemoryEditor(FakeMemoryRepository(), memory);
      var heard = 0;
      editor.addListener(() => heard++);
      editor.update('name', 'A');
      editor.update('name', 'Ann'); // same step: nothing new to say
      expect(heard, 1);
      editor.clearHistory();
      expect(heard, 2);
      expect(editor.canUndo, isFalse);
    });
  });

  group('the card', () {
    late FakeMemoryRepository repository;
    late FakeDictation dictation;

    Future<Memory> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repository = FakeMemoryRepository();
      dictation = FakeDictation();
      final added = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 11, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryEditScreen(
            memory: added,
            justMet: true,
            services: testServices(repository, dictation: dictation),
          ),
        ),
      );
      await tester.pump();
      return added;
    }

    IconButton button(WidgetTester tester, String tooltip) =>
        tester.widget<IconButton>(
          find.widgetWithIcon(
            IconButton,
            tooltip == 'Undo' ? Icons.undo : Icons.redo,
          ),
        );

    testWidgets('Undo and Redo start disabled; typing a name can be undone '
        'and redone', (tester) async {
      final added = await show(tester);
      expect(button(tester, 'Undo').onPressed, isNull);
      expect(button(tester, 'Redo').onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Ann');
      await tester.pump();
      expect(button(tester, 'Undo').onPressed, isNotNull);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.widgetWithText(TextField, 'Ann'), findsNothing);
      expect(repository.stored[added.id]!.field(MemoryField.name), '');

      await tester.tap(find.byTooltip('Redo'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.widgetWithText(TextField, 'Ann'), findsOneWidget);
      expect(repository.stored[added.id]!.field(MemoryField.name), 'Ann');
    });

    testWidgets('going to a related person leaves the Undo steps behind', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repository = FakeMemoryRepository();
      final bo = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 10, 1),
      );
      await repository.save(bo.withField('name', 'Bo'));
      final added = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 11, 1),
      );
      final ann = added.withField('name', 'Ann').withDetails([
        Detail(
          id: 'r',
          text: '',
          at: DateTime.utc(2026, 11, 1),
          type: DetailKind.relationship,
          label: 'brother',
          targetId: bo.id,
        ),
      ]);
      await repository.save(ann);
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryEditScreen(
            memory: ann,
            services: testServices(repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Ann'), 'Anne');
      await tester.pump();
      expect(button(tester, 'Undo').onPressed, isNotNull);

      await tester.ensureVisible(find.text('Bo').last);
      await tester.tap(find.text('Bo').last);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(button(tester, 'Undo').onPressed, isNull);
    });

    testWidgets('Undo waits while a field is listening', (tester) async {
      await show(tester);
      await tester.enterText(find.byType(TextField).first, 'Ann');
      await tester.pump();

      await tester.tap(find.byTooltip('Speak Name'));
      await tester.pump();
      expect(button(tester, 'Undo').onPressed, isNull);

      dictation.goQuiet();
      await tester.pump();
      expect(button(tester, 'Undo').onPressed, isNotNull);
    });
  });
}
