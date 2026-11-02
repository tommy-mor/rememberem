import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/matching_screen.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
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

  AppServices services() => AppServices(
    repository: repository,
    capture: PortraitCapture(
      repository: repository,
      faceLocator: _NoFaces(),
      workFolder: Directory.systemTemp,
    ),
    dictation: FakeDictation(),
    location: DeviceLocation(),
  );

  Future<Memory> person(
    String name,
    String place, {
    List<String> details = const [],
  }) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, repository.stored.length + 1),
      place: place,
    );
    final named = memory.withField('name', name).withDetails([
      for (final (i, text) in details.indexed)
        Detail(id: '${memory.id}-$i', text: text, at: DateTime.utc(2026)),
    ]);
    await repository.save(named);
    return named;
  }

  Future<void> showMatching(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: MatchingScreen(services: services(), routeObserver: observer),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repository = FakeMemoryRepository());

  testWidgets('lists active people only, with a count', (tester) async {
    await person('Alex', 'Cafe');
    final gone = await person('Gone', 'Cafe');
    await repository.trash(gone.id, DateTime(2026, 12, 1));

    await showMatching(tester);

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Gone'), findsNothing);
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('choosing a place narrows the list', (tester) async {
    await person('Alex', 'Cafe');
    await person('Sam', 'Park');
    await showMatching(tester);
    expect(find.text('2 people'), findsOneWidget);

    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Park').last);
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('details text filters, case-insensitively', (tester) async {
    await person('Alex', 'Cafe', details: ['Plays CHESS']);
    await person('Sam', 'Cafe', details: ['Tall']);
    await showMatching(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Details contain'),
      'chess',
    );
    await tester.pump();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);
  });

  testWidgets('a match opens their card; an edit shows on return', (
    tester,
  ) async {
    await person('Alex', 'Cafe');
    await showMatching(tester);

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Alex'),
      'Alex Davis',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Alex Davis'), findsOneWidget);
  });

  testWidgets('a chosen place that no one has any more keeps working', (
    tester,
  ) async {
    final alex = await person('Alex', 'Cafe');
    await person('Sam', 'Park');
    await showMatching(tester);
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cafe').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cafe'), 'Library');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No one matches.'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget); // still the chosen place
    expect(repository.stored[alex.id]!.latest.place, 'Library');
  });

  testWidgets('a load failure offers Retry, which recovers', (tester) async {
    repository = _FailingOnceRepository();
    await person('Alex', 'Cafe');

    await showMatching(tester);
    expect(find.text('Could not load people.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('the list has a Match people action that opens it', (
    tester,
  ) async {
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: MemoryListScreen(
          services: services(),
          routeObserver: observer,
          onMeetSomeone: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Match people'));
    await tester.pumpAndSettle();

    expect(find.byType(MatchingScreen), findsOneWidget);
  });
}
