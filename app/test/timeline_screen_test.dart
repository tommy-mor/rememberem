import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/timeline/timeline_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

class _FailingOnceRepository extends FakeMemoryRepository {
  bool fail = true;

  @override
  Future<List<Memory>> all() async {
    if (fail) {
      fail = false;
      throw const FormatException('corrupt record');
    }
    return super.all();
  }
}

void main() {
  late FakeMemoryRepository repository;

  Future<Memory> person(
    String name,
    DateTime capturedAt, {
    String place = '',
    String meeting = '',
    List<DateTime> details = const [],
  }) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: capturedAt,
      place: place,
      meeting: meeting,
    );
    final named = memory.withField('name', name).withDetails([
      for (final (i, at) in details.indexed)
        Detail(
          id: '${memory.id}-$i',
          text: 'detail',
          at: at,
          type: DetailKind.happening,
        ),
    ]);
    await repository.save(named);
    return named;
  }

  Future<void> showTimeline(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = RouteObserver<ModalRoute<void>>();
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
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: TimelineScreen(services: services, routeObserver: observer),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repository = FakeMemoryRepository());

  testWidgets('shows days and groups, leaves out the trashed, writes nothing', (
    tester,
  ) async {
    await person(
      'Alex Davis',
      DateTime(2026, 11, 1, 10),
      place: 'Stake Center',
      meeting: 'Sunday',
      // A happening on another day: without "Show details" only the day
      // he was met shows.
      details: [DateTime(2026, 11, 5, 10, 5)],
    );
    final quiet = await person('Sam', DateTime(2026, 10, 30, 9), place: 'Cafe');
    final gone = await person(
      'Gone',
      DateTime(2026, 11, 1, 11),
      details: [DateTime(2026, 11, 1, 11)],
    );
    await repository.trash(gone.id, DateTime(2026, 11, 2));
    repository.saves.clear();

    await showTimeline(tester);

    expect(find.text('Sunday, November 1, 2026'), findsOneWidget);
    expect(find.text('Friday, October 30, 2026'), findsOneWidget);
    expect(find.text('Stake Center - Sunday'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Thursday, November 5, 2026'), findsNothing);
    expect(find.text('Gone'), findsNothing);
    expect(repository.saves, isEmpty);
    expect(repository.purges, isEmpty);
    expect(repository.merges, isEmpty);
    expect(repository.deletedPhotos, isEmpty);
    expect(repository.stored[quiet.id]!.details, isEmpty);
  });

  testWidgets('tapping a date shows just that day', (tester) async {
    await person(
      'Alex',
      DateTime(2026, 11, 1, 10),
      details: [DateTime(2026, 11, 1, 10)],
    );
    await person(
      'Sam',
      DateTime(2026, 10, 30, 9),
      details: [DateTime(2026, 10, 30, 9)],
    );
    await showTimeline(tester);

    await tester.tap(find.text('Sunday, November 1, 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);
  });

  testWidgets('a miniature opens the card; a rename shows on return', (
    tester,
  ) async {
    await person(
      'Alex',
      DateTime(2026, 11, 1, 10),
      details: [DateTime(2026, 11, 1, 10)],
    );
    await showTimeline(tester);

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditScreen), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Alex'), 'Zed');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Zed'), findsOneWidget);
  });

  testWidgets('a load failure offers Retry, which recovers', (tester) async {
    repository = _FailingOnceRepository();
    await person('Alex', DateTime(2026, 11, 1, 10));

    await showTimeline(tester);
    expect(find.text('Could not load the timeline.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
  });
}
