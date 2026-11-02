import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_editor.dart';
import 'package:rememberem/src/memories/merge_picker_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  late GlobalKey<NavigatorState> navigator;

  Future<Memory> person(String name, DateTime capturedAt) async {
    final memory = await repository.add(photoJpeg: [], capturedAt: capturedAt);
    final named = memory.withField('name', name);
    await repository.save(named);
    return named;
  }

  Future<void> openCard(WidgetTester tester, Memory memory) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('list')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryEditScreen(
          memory: memory,
          services: testServices(repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mergeInto(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text('Merge with existing person'));
    await tester.tap(find.text('Merge with existing person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  setUp(() => repository = FakeMemoryRepository());

  group('editor close and reopen', () {
    test('a closed editor ignores changes; reopened, it saves again', () {
      fakeAsync((async) {
        final memory = Memory.captured(
          id: 'a',
          photoFileName: 'a.jpg',
          capturedAt: DateTime.utc(2026),
        );
        final editor = MemoryEditor(repository, memory);

        editor.close();
        editor.update('name', 'Ignored');
        editor.flush();
        async.elapse(const Duration(seconds: 1));
        expect(repository.saves, isEmpty);

        editor.reopen();
        editor.update('name', 'Saved');
        async.elapse(const Duration(seconds: 1));
        expect(repository.saves.single.field(MemoryField.name), 'Saved');
      });
    });
  });

  group('merge', () {
    testWidgets('saves pending typing, merges once, then returns to the list', (
      tester,
    ) async {
      final alex = await person('Alex', DateTime(2026, 10, 1));
      final newbie = await person('', DateTime(2026, 11, 1));
      await openCard(tester, newbie);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'A. Davis',
      );
      await mergeInto(tester, 'Alex');

      expect(repository.merges, [(alex.id, newbie.id)]);
      expect(repository.stored.keys, [alex.id]);
      expect(repository.stored[alex.id]!.field(MemoryField.name), 'A. Davis');
      expect(repository.stored[alex.id]!.encounters, hasLength(2));
      expect(find.text('list'), findsOneWidget);
      expect(find.text('Merged into Alex; name now A. Davis'), findsOneWidget);
      final savesOfDiscarded = repository.saves.where((m) => m.id == newbie.id);
      expect(savesOfDiscarded.last.field(MemoryField.name), 'A. Davis');
    });

    testWidgets('names only the target when the name stays the same', (
      tester,
    ) async {
      await person('Alex', DateTime(2026, 10, 1));
      final newbie = await person('', DateTime(2026, 11, 1));
      await openCard(tester, newbie);

      await mergeInto(tester, 'Alex');

      expect(find.text('Merged into Alex'), findsOneWidget);
    });

    testWidgets('a failed merge leaves the card working', (tester) async {
      await person('Alex', DateTime(2026, 10, 1));
      final newbie = await person('Sam', DateTime(2026, 11, 1));
      await openCard(tester, newbie);
      repository.failNextMerge = true;

      await mergeInto(tester, 'Alex');
      expect(find.text('Could not finish merging. Try again.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Sam'), 'Sam B');
      await tester.pump(const Duration(seconds: 1));
      expect(repository.stored[newbie.id]!.field(MemoryField.name), 'Sam B');
    });

    testWidgets('the picker offers neither this person nor trashed people', (
      tester,
    ) async {
      final me = await person('Me', DateTime(2026, 1, 1));
      await person('Alex', DateTime(2026, 2, 1));
      final gone = await person('Gone', DateTime(2026, 3, 1));
      await repository.trash(gone.id, DateTime(2026, 4, 1));

      await tester.pumpWidget(
        MaterialApp(
          home: MergePickerScreen(repository: repository, excludeId: me.id),
        ),
      );
      await tester.pump();

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
      expect(find.text('Gone'), findsNothing);
    });
  });

  group('pictures', () {
    Future<Memory> twoPictures() async {
      final alex = await person('Alex', DateTime(2026, 10, 1));
      final again = await person('', DateTime(2026, 11, 1));
      return repository.merge(alex.id, again.id);
    }

    testWidgets('the newest is the photo; the others are listed under it', (
      tester,
    ) async {
      final alex = await twoPictures();
      await openCard(tester, alex);

      final dates = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(dates, ['Thursday, October 1, 2026']);
      expect(
        tester.getTopLeft(find.text('Thursday, October 1, 2026')).dy,
        lessThan(tester.getTopLeft(find.widgetWithText(TextField, 'Name')).dy),
      );
    });

    testWidgets('delete with Undo restores it and keeps the file', (
      tester,
    ) async {
      final alex = await twoPictures();
      await openCard(tester, alex);

      await tester.tap(find.byTooltip('Open this picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete picture'));
      await tester.pumpAndSettle();
      expect(repository.stored[alex.id]!.encounters, hasLength(1));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.stored[alex.id]!.encounters, hasLength(2));
      expect(repository.deletedPhotos, isEmpty);
    });

    testWidgets('the photo file is deleted once Undo has gone', (tester) async {
      final alex = await twoPictures();
      await openCard(tester, alex);
      final newest = alex.latest.photoFileName;

      await tester.tap(find.byTooltip('Open this picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete picture'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10)); // snackbar times out
      await tester.pumpAndSettle();

      expect(repository.deletedPhotos, [newest]);
      // The older picture now represents them.
      expect(find.textContaining('Oct 1,'), findsOneWidget);
    });

    testWidgets('the last picture cannot be deleted', (tester) async {
      final alex = await person('Alex', DateTime(2026, 10, 1));
      await openCard(tester, alex);

      await tester.tap(find.byTooltip('Open this picture'));
      await tester.pumpAndSettle();

      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Delete picture'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.text('A person needs at least one picture.'), findsOneWidget);
    });
  });

  testWidgets('a second picture delete replaces the first Undo, and both '
      'files go once Fred leaves', (tester) async {
    final a = await person('Alex', DateTime(2026, 9, 1));
    final b = await person('', DateTime(2026, 10, 1));
    final c = await person('', DateTime(2026, 11, 1));
    await repository.merge(a.id, b.id);
    final alex = await repository.merge(a.id, c.id);
    await openCard(tester, alex);

    // The newest picture is the photo; after its delete the next one is.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Open this picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete picture'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Undo'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repository.deletedPhotos, hasLength(2));
    expect(repository.stored[a.id]!.encounters, hasLength(1));
  });
}
