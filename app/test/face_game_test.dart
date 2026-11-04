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
import 'fakes/fake_game_feedback.dart';
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

  late FakeGameFeedback feedback;

  Future<void> showGame(
    WidgetTester tester, {
    int turns = 10,
    Duration pause = Duration.zero,
  }) async {
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
          feedback: feedback,
          pauseAfterRight: pause,
        ),
      ),
    );
    await tester.pump();
  }

  /// Taps [name] and lets the game move on (the pause is zero here).
  Future<void> pick(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(Duration.zero);
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

  setUp(() {
    repository = FakeMemoryRepository();
    feedback = FakeGameFeedback();
  });

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

  testWidgets('with a screen reader the names wait for Show names, and '
      'each answer is shown as well as said', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = showing(tester);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text(nameOf(person)), findsNothing);

    await tester.tap(find.text('Show names'));
    await tester.pump();
    expect(find.text(nameOf(person)), findsOneWidget);

    final other = [
      'Ann',
      'Bo',
      'Cy',
      'Di',
    ].firstWhere((n) => n != nameOf(person));
    await pick(tester, other);
    expect(find.text('Not $other.'), findsOneWidget);
  });

  testWidgets('turning the screen reader off mid-reveal starts the countdown', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = showing(tester);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(find.text('Show names'), findsOneWidget);
    await reveal(tester);

    expect(find.text(nameOf(person)), findsOneWidget);
  });

  testWidgets('first try right adds a point and stamps the time', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = showing(tester);
    await reveal(tester);

    await pick(tester, nameOf(person));

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
    await pick(tester, nameOf(person));

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
    await pick(
      tester,
      nameOf(person),
    ); // the answer is saved; the next turn is loading
    await tester.tap(find.text(nameOf(person)), warnIfMissed: false);
    await tester.pump();
    slow.hold!.complete();
    slow.hold = null;
    await tester.pump();
    await tester.pump();

    expect(repository.answers, [(person.id, true)]);
    expect(repository.stored[person.id]!.points, 1);
    expect(find.text('Turn 2 of 4'), findsOneWidget);
  });

  testWidgets('no one is asked twice: five people make a five-turn game', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di', 'Ed']);
    await showGame(tester);
    final asked = <String>[];

    for (var turn = 1; turn <= 5; turn++) {
      expect(find.text('Turn $turn of 5'), findsOneWidget);
      final person = showing(tester);
      asked.add(person.id);
      await reveal(tester);
      await pick(tester, nameOf(person));
    }

    expect(asked.toSet(), hasLength(5));
    expect(find.text('Done: 5 of 5 right first try.'), findsOneWidget);
    expect(repository.answers, hasLength(5));
  });

  testWidgets('with more people than turns the game stops at the setting', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di', 'Ed', 'Flo', 'Gus']);
    await showGame(tester, turns: 5);

    for (var turn = 1; turn <= 5; turn++) {
      expect(find.text('Turn $turn of 5'), findsOneWidget);
      await reveal(tester);
      await pick(tester, nameOf(showing(tester)));
    }

    expect(find.text('Done: 5 of 5 right first try.'), findsOneWidget);
  });

  testWidgets('right: a chime, then a one-second pause; wrong: a nope', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester, pause: const Duration(seconds: 1));
    final person = showing(tester);
    await reveal(tester);
    final wrong = [
      'Ann',
      'Bo',
      'Cy',
      'Di',
    ].firstWhere((n) => n != nameOf(person));

    await tester.tap(find.text(wrong));
    await tester.pump();
    expect(feedback.given, ['wrong']);

    await pick(tester, nameOf(person));
    expect(feedback.given, ['wrong', 'right']);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Turn 1 of 4'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Turn 2 of 4'), findsOneWidget);
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
      await pick(tester, nameOf(person));
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
    // Not settle: the Show countdown animates.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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
      final button = find.widgetWithText(OutlinedButton, 'Faces');
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        find.text('Name at least 4 different people to practice faces.'),
        findsOneWidget,
      );
    });

    testWidgets('a screen reader hears that the face game needs sight', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await showList(tester);

      expect(
        find.bySemanticsLabel(MemoryListScreen.facesLabel),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('with four names it opens the game', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await showList(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Faces'));
      await tester.pumpAndSettle();

      expect(find.byType(FaceGameScreen), findsOneWidget);
    });
  });
}
