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
import 'fakes/fake_game_feedback.dart';
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
        home: DetailGameScreen(
          repository: repository,
          planner: DetailQuizPlanner(Random(1), () => now),
          clock: () => now,
          turns: turns,
          feedback: feedback,
          pauseAfterRight: pause,
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
        w.image is ResizeImage &&
        switch ((w.image as ResizeImage).imageProvider) {
          final FileImage f => f.file.path.endsWith(person.photoFileName),
          _ => false,
        },
  );

  Future<void> reveal(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 3));

  /// Taps [person]'s card and lets the game move on (zero pause here).
  Future<void> pick(WidgetTester tester, Memory person) async {
    await tester.tap(card(person));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  setUp(() {
    repository = FakeMemoryRepository();
    feedback = FakeGameFeedback();
  });

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
    // The detail stays above the choices, with its kind.
    expect(find.textContaining('about #'), findsOneWidget);
    expect(find.text('FACT'), findsOneWidget);
  });

  testWidgets('first try right scores the detail', (tester) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = subject(tester);
    await reveal(tester);

    await pick(tester, person);

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
    await pick(tester, person);

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
    await pick(tester, person);

    expect(repository.detailAnswers, [
      (person.id, person.details.single.id, false),
    ]);
    expect(repository.stored[person.id]!.details.single.points, 0);
  });

  testWidgets('with accessible navigation reported, Show people still '
      'presses itself', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = subject(tester);

    await reveal(tester);
    expect(card(person), findsOneWidget);
  });

  testWidgets('a screen reader can choose a card and hears each answer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester);
    final person = subject(tester);
    await reveal(tester);
    final other = repository.stored.values.firstWhere((m) => m.id != person.id);

    // Fails unless the card offers a tap to the screen reader.
    tester.semantics.tap(find.semantics.byLabel(other.displayName));
    await tester.pump();

    expect(find.text('Not ${other.displayName}.'), findsOneWidget);
    expect(repository.detailAnswers.single.$3, isFalse);
    semantics.dispose();
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
    await pick(tester, person);
    await tester.tap(card(person), warnIfMissed: false);
    await tester.pump();
    slow.hold!.complete();
    slow.hold = null;
    await tester.pump();
    await tester.pump();

    expect(repository.detailAnswers, hasLength(1));
    expect(find.text('Turn 2 of 4'), findsOneWidget);
  });

  testWidgets('no detail twice: five details make a five-turn game; failed '
      'saves never stop it', (tester) async {
    repository = _FailingAnswers();
    await people(['Ann', 'Bo', 'Cy', 'Di', 'Ed']);
    await showGame(tester);
    final asked = <String>{};

    for (var turn = 1; turn <= 5; turn++) {
      expect(find.text('Turn $turn of 5'), findsOneWidget);
      final person = subject(tester);
      asked.add(person.id);
      await reveal(tester);
      await pick(tester, person);
    }

    expect(asked, hasLength(5));
    expect(find.text('5 of 5 right first try'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right: a chime and a one-second pause; wrong: a nope', (
    tester,
  ) async {
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await showGame(tester, pause: const Duration(seconds: 1));
    final person = subject(tester);
    await reveal(tester);
    final other = repository.stored.values.firstWhere((m) => m.id != person.id);

    await tester.tap(card(other));
    await tester.pump();
    await pick(tester, person);
    expect(feedback.given, ['wrong', 'right']);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Turn 1 of 4'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Turn 2 of 4'), findsOneWidget);
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
    final button = find.widgetWithText(OutlinedButton, 'Details');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

    await repository.add(photoJpeg: [], capturedAt: DateTime(2026, 2, 1));
    await tester.pumpWidget(const SizedBox());
    await showList();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Details'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailGameScreen), findsOneWidget);
  });

  testWidgets('a relationship reads "My boss is Bo"; its owner is the answer', (
    tester,
  ) async {
    final ids = <String>[];
    for (final name in ['Ann', 'Bo', 'Cy', 'Di']) {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, ids.length + 1),
      );
      await repository.save(m.withField('name', name));
      ids.add(m.id);
    }
    final ann = repository.stored[ids[0]]!;
    await repository.save(
      ann.withDetails([
        Detail(
          id: 'r',
          text: 'Since 2020',
          at: DateTime.utc(2026),
          type: DetailKind.relationship,
          label: 'boss',
          targetId: ids[1],
        ),
      ]),
    );
    await showGame(tester);

    expect(find.text('My boss is Bo: Since 2020'), findsOneWidget);
    expect(find.text('RELATIONSHIP'), findsOneWidget);
    await reveal(tester);
    await pick(tester, repository.stored[ids[0]]!);

    expect(repository.detailAnswers, [(ids[0], 'r', true)]);
  });

  group('layout', () {
    Future<void> showAt(
      WidgetTester tester,
      Size size, {
      double scale = 1,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: DetailGameScreen(
            repository: repository,
            planner: DetailQuizPlanner(Random(1), () => now),
            clock: () => now,
            pauseAfterRight: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      await reveal(tester);
    }

    for (final (name, size, scale) in const [
      ('on 360 x 640', Size(360, 640), 1.0),
      ('on its side at 568 x 320', Size(568, 320), 1.0),
      ('at text scale 2.0 on 320 x 568', Size(320, 568), 2.0),
    ]) {
      testWidgets('four photos at least 120 dp tall, all reachable $name', (
        tester,
      ) async {
        await people(['Ann', 'Bo', 'Cy', 'Di']);
        await showAt(tester, size, scale: scale);

        final images = find.byType(Image);
        expect(images, findsNWidgets(4));
        for (final image in images.evaluate()) {
          final box = image.renderObject! as RenderBox;
          expect(box.size.height, inInclusiveRange(120, 188));
        }
        for (final name in ['Ann', 'Bo', 'Cy', 'Di']) {
          final finder = find.text(name);
          await tester.dragUntilVisible(
            finder,
            find.byType(Scrollable).first,
            const Offset(0, -80),
          );
          final rect = tester.getRect(finder);
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.top, greaterThanOrEqualTo(0));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a wrong card is dimmed, disabled and "not this one"; the '
        'right one has a corner check and is selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await showAt(tester, const Size(360, 800));
      final answer = subject(tester);
      final wrong = repository.stored.values.firstWhere(
        (m) => m.id != answer.id,
      );

      await tester.tap(card(wrong));
      await tester.pump();

      final name = wrong.field(MemoryField.name);
      expect(find.bySemanticsLabel('$name, not this one'), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: card(wrong), matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        0.35,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.tap(card(answer));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.text(answer.field(MemoryField.name))),
        matchesSemantics(
          label: '${answer.field(MemoryField.name)}, right',
          isButton: true,
          isEnabled: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
        ),
      );
      semantics.dispose();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('during the countdown the four people stay hidden', (
      tester,
    ) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: DetailGameScreen(
            repository: repository,
            planner: DetailQuizPlanner(Random(1), () => now),
            clock: () => now,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(Image), findsNothing);
      for (final name in ['Ann', 'Bo', 'Cy', 'Di']) {
        expect(find.text(name), findsNothing);
      }
      expect(find.text('Show people'), findsOneWidget);
      expect(find.text('Who is this about?'), findsOneWidget);
    });

    testWidgets('a long detail shrinks to 19 sp, then is cut at three lines', (
      tester,
    ) async {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, 1),
      );
      await repository.save(
        m.withField('name', 'Ann').withDetails([
          Detail(id: 'long', text: 'word ' * 80, at: DateTime.utc(2026)),
        ]),
      );
      for (final name in ['Bo', 'Cy', 'Di']) {
        final other = await repository.add(
          photoJpeg: [],
          capturedAt: DateTime(2026, 1, 2),
        );
        await repository.save(other.withField('name', name));
      }
      await showAt(tester, const Size(360, 640));
      final text = tester.widget<Text>(find.textContaining('word word'));
      expect(text.style?.fontSize, 19);
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
