import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

/// Holds the next all() open while [hold] is set, like a slow disk.
class _SlowNextTurn extends FakeMemoryRepository {
  Completer<void>? hold;

  @override
  Future<List<Memory>> all() async {
    final wait = hold;
    if (wait != null) await wait.future;
    return super.all();
  }
}

class _FailingAnswers extends FakeMemoryRepository {
  @override
  Future<void> recordAnswer(
    String id, {
    required bool correctFirstTry,
    required DateTime at,
  }) async => throw const FileSystemException('disk full');
}

void main() {
  late FakeMemoryRepository repository;
  final now = DateTime.utc(2026, 11, 1, 12);

  Future<void> people(List<String> names, {int points = 0}) async {
    for (final name in names) {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, repository.stored.length + 1),
      );
      await repository.save(m.withField('name', name).withScore(points, null));
    }
  }

  Future<void> showGame(WidgetTester tester, {int turns = 10}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FaceGameScreen(
          repository: repository,
          planner: FaceQuizPlanner(Random(1), () => now),
          clock: () => now,
          turns: turns,
        ),
      ),
    );
    await tester.pump();
  }

  /// The person whose face is showing, from the photo's file name.
  Memory showing(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image)).image as FileImage;
    final id = image.file.uri.pathSegments.last.split('.').first;
    return repository.stored[id]!;
  }

  String nameOf(Memory m) => m.field(MemoryField.name);

  Future<void> reveal(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3));

  setUp(() => repository = FakeMemoryRepository());

  testWidgets('the name stays hidden until three seconds have passed', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = showing(tester);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text(nameOf(person)), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FilledButton), findsNWidgets(4));
    expect(find.text(nameOf(person)), findsOneWidget);
  });

  testWidgets('first try right adds a point and stamps the time', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = showing(tester);
    await reveal(tester);

    await tester.tap(find.text(nameOf(person)));
    await tester.pump();

    expect(repository.stored[person.id]!.points, 1);
    expect(repository.stored[person.id]!.lastCorrectDate, now);
  });

  testWidgets('a miss resets points at once; the later right answer earns '
      'nothing; two misses write once', (tester) async {
    await people(['Ann', 'Bo', 'Cy', 'Di'], points: 4);
    await showGame(tester);
    final person = showing(tester);
    await reveal(tester);
    final wrong = [
      'Ann',
      'Bo',
      'Cy',
      'Di',
    ].where((n) => n != nameOf(person)).toList();

    await tester.tap(find.text(wrong[0]));
    await tester.pump();
    expect(repository.stored[person.id]!.points, 0);
    await tester.tap(find.text(wrong[1]));
    await tester.pump();
    await tester.tap(find.text(nameOf(person)));
    await tester.pump();

    expect(repository.answers, [(person.id, false)]);
    expect(repository.stored[person.id]!.points, 0);
    expect(repository.stored[person.id]!.lastCorrectDate, isNull);
  });

  testWidgets('a second tap while the next turn loads scores nothing', (
    tester,
  ) async {
    repository = _SlowNextTurn();
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = showing(tester);
    await reveal(tester);
    final slow = repository as _SlowNextTurn;

    slow.hold = Completer<void>();
    await tester.tap(find.text(nameOf(person)));
    await tester.pump(); // the answer is saved; the next turn is loading
    await tester.tap(find.text(nameOf(person)), warnIfMissed: false);
    await tester.pump();
    slow.hold!.complete();
    slow.hold = null;
    await tester.pump();

    expect(repository.answers, [(person.id, true)]);
    expect(repository.stored[person.id]!.points, 1);
    expect(find.text('Turn 2 of 10'), findsOneWidget);
  });

  testWidgets('a game is exactly ten turns, then a gentle finish', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di', 'Ed']);
    await showGame(tester);

    for (var turn = 1; turn <= 10; turn++) {
      expect(find.text('Turn $turn of 10'), findsOneWidget);
      final person = showing(tester);
      await reveal(tester);
      await tester.tap(find.text(nameOf(person)));
      await tester.pump();
    }

    expect(find.text('Done: 10 of 10 right first try.'), findsOneWidget);
    expect(repository.answers, hasLength(10));
  });

  testWidgets('failed saves never stop the game or count as points', (
    tester,
  ) async {
    repository = _FailingAnswers();
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester, turns: 2);

    for (var turn = 0; turn < 2; turn++) {
      final person = showing(tester);
      await reveal(tester);
      await tester.tap(find.text(nameOf(person)));
      await tester.pump();
    }

    expect(find.text('Done: 0 of 2 right first try.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving mid-reveal leaves no timer and writes nothing', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    expect(repository.answers, isEmpty);
  });

  testWidgets('inactive hides the face; resume reveals it afresh; paused '
      'ends the game', (tester) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    final navigator = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('list')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => FaceGameScreen(
          repository: repository,
          planner: FaceQuizPlanner(Random(1), () => now),
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(FilledButton), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FilledButton), findsNWidgets(4));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(repository.answers, isEmpty);
  });

  group('list control', () {
    Future<void> showList(WidgetTester tester) async {
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: MemoryListScreen(
            services: AppServices(
              repository: repository,
              capture: PortraitCapture(
                repository: repository,
                faceLocator: _NoFaces(),
                workFolder: Directory.systemTemp,
              ),
              dictation: FakeDictation(),
              location: DeviceLocation(),
            ),
            routeObserver: observer,
            onMeetSomeone: () {},
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('needs four different names; same names count once', (
      tester,
    ) async {
      await people(['Ann', 'Ann', 'Bo', 'Cy']);
      await showList(tester);
      final button = find.widgetWithText(OutlinedButton, 'Practice faces');
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        find.text('Name at least 4 different people to practice faces.'),
        findsOneWidget,
      );
    });

    testWidgets('with four names it opens the game', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await showList(tester);

      await tester.tap(find.text('Practice faces'));
      await tester.pumpAndSettle();

      expect(find.byType(FaceGameScreen), findsOneWidget);
    });
  });
}
