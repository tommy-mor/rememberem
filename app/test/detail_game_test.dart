import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/practice/detail_game_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

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
  Future<void> recordDetailAnswer(
    String memoryId,
    String detailId, {
    required bool correctFirstTry,
    required DateTime at,
  }) async => throw const FileSystemException('disk full');
}

void main() {
  late FakeMemoryRepository repository;
  final now = DateTime.utc(2026, 11, 1, 12);

  /// People named [names]; each with one detail "about <name>" (by index).
  Future<void> people(List<String> names, {int points = 0}) async {
    for (final (i, name) in names.indexed) {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, i + 1),
      );
      await repository.save(
        m.withField('name', name).withDetails([
          Detail(
            id: 'd$i',
            text: 'about #$i',
            at: DateTime.utc(2026),
            points: points,
          ),
        ]),
      );
    }
  }

  Future<void> showGame(WidgetTester tester, {int turns = 10}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DetailGameScreen(
          repository: repository,
          planner: DetailQuizPlanner(Random(1), () => now),
          clock: () => now,
          turns: turns,
        ),
      ),
    );
    await tester.pump();
  }

  /// The owner of the detail on screen, from its "about #i" text.
  Memory subject(WidgetTester tester) {
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.startsWith('about #'));
    final index = int.parse(text.substring('about #'.length));
    return repository.stored.values.firstWhere(
      (m) => m.details.any((d) => d.id == 'd$index'),
    );
  }

  /// The card showing [person]'s photo (exact, even when names repeat).
  Finder card(Memory person) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is FileImage &&
        (w.image as FileImage).file.path.endsWith(person.photoFileName),
  );

  Future<void> reveal(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3));

  setUp(() => repository = FakeMemoryRepository());

  testWidgets('only the detail shows at first; four cards come at 3 s', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    expect(find.textContaining('about #'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(Image), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.textContaining('about #'), findsNothing);
  });

  testWidgets('first try right scores the detail', (tester) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = subject(tester);
    await reveal(tester);

    await tester.tap(card(person));
    await tester.pump();

    final detail = repository.stored[person.id]!.details.single;
    expect(detail.points, 1);
    expect(detail.lastCorrectDate, now);
  });

  testWidgets('two people named Sarah are two cards; only the right one '
      'scores', (tester) async {
    await people(['Sarah', 'Sarah', 'Cy', 'Di']);
    await showGame(tester);
    final person = subject(tester);
    await reveal(tester);

    final sarahs = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Sarah',
    );
    expect(sarahs, findsNWidgets(2));
    await tester.tap(card(person));
    await tester.pump();

    expect(repository.detailAnswers, [
      (person.id, person.details.single.id, true),
    ]);
  });

  testWidgets('a miss resets the detail at once, writing once per turn', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di'], points: 4);
    await showGame(tester);
    final person = subject(tester);
    await reveal(tester);
    final others = repository.stored.values
        .where((m) => m.id != person.id)
        .toList();

    await tester.tap(card(others[0]));
    await tester.pump();
    expect(repository.stored[person.id]!.details.single.points, 0);
    await tester.tap(card(others[1]));
    await tester.pump();
    await tester.tap(card(person));
    await tester.pump();

    expect(repository.detailAnswers, [
      (person.id, person.details.single.id, false),
    ]);
    expect(repository.stored[person.id]!.details.single.points, 0);
  });

  testWidgets('a second tap while the next turn loads scores nothing', (
    tester,
  ) async {
    repository = _SlowNextTurn();
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = subject(tester);
    await reveal(tester);
    final slow = repository as _SlowNextTurn;

    slow.hold = Completer<void>();
    await tester.tap(card(person));
    await tester.pump();
    await tester.tap(card(person), warnIfMissed: false);
    await tester.pump();
    slow.hold!.complete();
    slow.hold = null;
    await tester.pump();

    expect(repository.detailAnswers, hasLength(1));
    expect(find.text('Turn 2 of 10'), findsOneWidget);
  });

  testWidgets('ten turns, then a finish; failed saves never stop it', (
    tester,
  ) async {
    repository = _FailingAnswers();
    await people(['Ann', 'Bo', 'Cy', 'Di', 'Ed']);
    await showGame(tester);

    for (var turn = 1; turn <= 10; turn++) {
      expect(find.text('Turn $turn of 10'), findsOneWidget);
      final person = subject(tester);
      await reveal(tester);
      await tester.tap(card(person));
      await tester.pump();
    }

    expect(find.text('Done: 0 of 10 right first try.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive hides the detail; resume reveals it afresh', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('about #'), findsNothing);
    expect(find.byType(Image), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('about #'), findsOneWidget);
    await reveal(tester);
    expect(find.byType(Image), findsNWidgets(4));
  });

  testWidgets('the list offers Practice details once there is a detail and '
      'four people', (tester) async {
    await people(['Ann', 'Bo', 'Cy']);
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
    Future<void> showList() async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: MemoryListScreen(
            services: services,
            routeObserver: observer,
            onMeetSomeone: () {},
          ),
        ),
      );
      await tester.pump();
    }

    await showList();
    final button = find.widgetWithText(OutlinedButton, 'Practice details');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

    await repository.add(photoJpeg: [], capturedAt: DateTime(2026, 2, 1));
    await tester.pumpWidget(const SizedBox());
    await showList();
    await tester.tap(find.text('Practice details'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailGameScreen), findsOneWidget);
  });
}
