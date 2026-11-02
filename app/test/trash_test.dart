import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
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

  Future<void> trashFromPage(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();
  }

  testWidgets('trash on the person page saves, goes back without them, and '
      'Undo brings them back on their page', (tester) async {
    await person('Alex');
    await person('Sam');
    await showList(tester);
    expect(find.byTooltip('Move to trash'), findsNothing); // not on the list

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Meeting'), 'Choir');
    await tester.tap(find.byTooltip('Move to trash'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryListScreen), findsOneWidget);
    expect(find.byType(MemoryEditScreen), findsNothing);
    expect(find.text('Sam'), findsNothing);
    expect(find.text('Moved Sam to trash'), findsOneWidget);
    final trashed = (await repository.trashed()).single;
    expect(trashed.field(MemoryField.meeting), 'Choir');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditScreen), findsOneWidget);
    expect(await repository.trashed(), isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('opening the Trash hides a pending Undo', (tester) async {
    await person('Sam');
    await showList(tester);
    await trashFromPage(tester, 'Sam');
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
