import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/trash/trash_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

/// Lets a test hold the next all() call open and finish it later.
class _SlowListRepository extends FakeMemoryRepository {
  Completer<void>? gate;

  @override
  Future<List<Memory>> all() async {
    final result = await super.all();
    final wait = gate;
    gate = null;
    if (wait != null) await wait.future;
    return result;
  }
}

void main() {
  late FakeMemoryRepository repository;

  Future<Memory> person(String name) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, repository.stored.length + 1),
    );
    final named = memory.withField('name', name);
    await repository.save(named);
    return named;
  }

  Future<void> showList(WidgetTester tester) async {
    final services = AppServices(
      repository: repository,
      capture: PortraitCapture(
        repository: repository,
        faceLocator: _NoFaces(),
        workFolder: Directory.systemTemp,
      ),
      dictation: FakeDictation(),
      location: DeviceLocation(),
    );
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: MemoryListScreen(
          services: services,
          routeObserver: observer,
          onMeetSomeone: () {},
          clock: () => DateTime.utc(2026, 11, 5),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> showTrash(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TrashScreen(repository: repository)),
    );
    await tester.pump();
  }

  setUp(() => repository = FakeMemoryRepository());

  testWidgets('trash removes the row at once; Undo brings it back', (
    tester,
  ) async {
    await person('Alex');
    await person('Sam');
    await showList(tester);

    await tester.tap(find.byTooltip('Move to trash').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sam'), findsNothing);
    expect(find.text('Moved Sam to trash'), findsOneWidget);
    expect((await repository.trashed()).single.field(MemoryField.name), 'Sam');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
    expect(await repository.trashed(), isEmpty);
  });

  testWidgets('an old reload finishing late cannot hide an undone trash', (
    tester,
  ) async {
    repository = _SlowListRepository();
    await person('Sam');
    await showList(tester);
    final slow = repository as _SlowListRepository;

    final held = Completer<void>();
    slow.gate = held;
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);

    held.complete(); // the stale reload (taken while trashed) lands last
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('opening the Trash hides a pending Undo', (tester) async {
    await person('Sam');
    await showList(tester);
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.byTooltip('Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsNothing);
    expect(find.text('Sam'), findsOneWidget); // listed in the trash
  });

  testWidgets('empty trash says so', (tester) async {
    await showTrash(tester);

    expect(find.text('Trash is empty.'), findsOneWidget);
  });

  testWidgets('Restore moves a person back out of the trash', (tester) async {
    final alex = await person('Alex');
    await repository.trash(alex.id, DateTime.utc(2026, 11, 5));
    await showTrash(tester);

    await tester.tap(find.byTooltip('Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Trash is empty.'), findsOneWidget);
    expect((await repository.all()).single.id, alex.id);
  });

  testWidgets('Delete forever asks first; Cancel keeps, Delete purges once', (
    tester,
  ) async {
    final alex = await person('Alex');
    await repository.trash(alex.id, DateTime.utc(2026, 11, 5));
    await showTrash(tester);

    await tester.tap(find.byTooltip('Delete forever'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Alex forever?'), findsOneWidget);
    expect(find.textContaining('no longer link to them'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.purges, isEmpty);
    expect(repository.stored[alex.id], isNotNull);
    expect(find.text('Alex'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.purges, [alex.id]);
    expect(find.text('Trash is empty.'), findsOneWidget);
  });
}
