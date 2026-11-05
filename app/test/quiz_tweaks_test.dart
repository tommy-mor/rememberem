import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/pill_button.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/practice/answer_row.dart';
import 'package:rememberem/src/practice/countdown_button.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem/src/practice/filtered_practice_screen.dart';
import 'package:rememberem/src/practice/mute_button.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  group('CountdownButton', () {
    late int presses;

    Future<void> show(WidgetTester tester, {bool running = true}) async {
      presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountdownButton(
              label: 'Show names',
              duration: const Duration(seconds: 3),
              running: running,
              onPressed: () => presses++,
            ),
          ),
        ),
      );
    }

    testWidgets('fills, then presses itself once at the end', (tester) async {
      await show(tester);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(presses, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(presses, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(presses, 1);
    });

    testWidgets('the drain bar is drawn in the theme colour, not gold', (
      tester,
    ) async {
      await show(tester);
      final bar = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(CountdownButton),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color.a == 1 && w.child == null,
          ),
        ),
      );
      final scheme = Theme.of(tester.element(find.byType(CountdownButton)))
          .colorScheme;
      expect(bar.color, scheme.primary);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a tap presses it at once, and only once', (tester) async {
      await show(tester);
      await tester.tap(find.text('Show names'));
      await tester.pump(const Duration(seconds: 5));
      expect(presses, 1);
    });

    testWidgets('not running (a screen reader), it waits for a tap', (
      tester,
    ) async {
      await show(tester, running: false);
      await tester.pump(const Duration(seconds: 10));
      expect(presses, 0);
      await tester.tap(find.text('Show names'));
      expect(presses, 1);
    });

    testWidgets('leaving the app stops it; coming back starts it afresh', (
      tester,
    ) async {
      await show(tester);
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 5));
      expect(presses, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(presses, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(presses, 1);
    });
  });

  group('games', () {
    late FakeMemoryRepository repository;

    Future<void> people(List<String> names) async {
      for (final name in names) {
        final m = await repository.add(
          photoJpeg: [],
          capturedAt: DateTime(2026, 1, repository.stored.length + 1),
        );
        await repository.save(m.withField('name', name));
      }
    }

    setUp(() => repository = FakeMemoryRepository());

    testWidgets('with the show delay off, the names show at once', (
      tester,
    ) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await tester.pumpWidget(
        MaterialApp(
          home: FaceGameScreen(
            repository: repository,
            planner: FaceQuizPlanner(Random(1), DateTime.now),
            showDelay: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CountdownButton), findsNothing);
      expect(find.byType(AnswerRow), findsNWidgets(4));
    });

    testWidgets('mute flips the Sounds setting and its icon', (tester) async {
      final settings = AppSettingsController();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MuteButton(settings))),
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Mute sounds'));
      await tester.pump();
      expect(settings.value.sounds, isFalse);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      // It follows Settings too.
      settings.value = settings.value.copyWith(sounds: true);
      await tester.pump();
      expect(find.byTooltip('Mute sounds'), findsOneWidget);
    });

    testWidgets('the game has a mute button beside Home', (tester) async {
      await people(['Ann', 'Bo', 'Cy', 'Di']);
      await tester.pumpWidget(
        MaterialApp(
          home: FaceGameScreen(
            repository: repository,
            planner: FaceQuizPlanner(Random(1), DateTime.now),
            settings: AppSettingsController(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MuteButton), findsOneWidget);
      expect(find.byTooltip('Home'), findsOneWidget);
    });
  });

  group('a quiz on a filtered list', () {
    late FakeMemoryRepository repository;
    late AppServices services;

    Future<void> person(String name, String place) async {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, repository.stored.length + 1),
        place: place,
      );
      await repository.save(m.withField('name', name));
    }

    Future<void> showList(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryListScreen(
            services: services,
            routeObserver: RouteObserver<ModalRoute<void>>(),
            onMeetSomeone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    FaceGameScreen game(WidgetTester tester) =>
        tester.widget<FaceGameScreen>(find.byType(FaceGameScreen));

    setUp(() async {
      repository = FakeMemoryRepository();
      services = testServices(repository);
      for (final n in ['Ann', 'Bo', 'Cy', 'Di']) {
        await person(n, 'Cafe');
      }
      await person('Ed', 'Park');
    });

    testWidgets('with no filter, Faces starts at once', (tester) async {
      await showList(tester);
      await tester.tap(find.text('Faces'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FilteredPracticeScreen), findsNothing);
      expect(game(tester).pool, isNull);
    });

    testWidgets('says how the list is filtered and plays only those people', (
      tester,
    ) async {
      services.listFilters.show([const PlaceFilter('Cafe')]);
      await showList(tester);

      await tester.tap(find.text('Faces'));
      await tester.pumpAndSettle();
      expect(find.byType(FilteredPracticeScreen), findsOneWidget);
      expect(find.text('Place: Cafe'), findsOneWidget);
      // The filter shows as a pill, in the strip under the bar.
      expect(find.widgetWithText(PillButton, 'Place: Cafe'), findsOneWidget);
      expect(find.text('4 people, 4 faces to ask.'), findsOneWidget);

      await tester.tap(find.text('Play with the filtered list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FilteredPracticeScreen), findsNothing);
      final ids = {
        for (final m in repository.stored.values)
          if (m.latest.place == 'Cafe') m.id,
      };
      expect(game(tester).pool, ids);
    });

    testWidgets('"Play with everyone" ignores the filter', (tester) async {
      services.listFilters.show([const PlaceFilter('Cafe')]);
      await showList(tester);
      await tester.tap(find.text('Faces'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play with everyone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(game(tester).pool, isNull);
    });

    testWidgets('a list too small to play says why', (tester) async {
      services.listFilters.show([const PlaceFilter('Park')]);
      await showList(tester);
      await tester.tap(find.text('Faces'));
      await tester.pumpAndSettle();

      final play = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Play with the filtered list'),
      );
      expect(play.onPressed, isNull);
      expect(
        find.text('Needs 4 different names; this list has 1.'),
        findsOneWidget,
      );
    });
  });

  group('a pool limits who is asked', () {
    late FakeMemoryRepository repository;

    Future<Memory> person(String name, {String? detail}) async {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, repository.stored.length + 1),
      );
      final named = m.withField('name', name).withDetails([
        if (detail != null)
          Detail(id: '${m.id}-d', text: detail, at: DateTime.utc(2026)),
      ]);
      await repository.save(named);
      return named;
    }

    setUp(() => repository = FakeMemoryRepository());

    testWidgets('faces: every face and choice comes from the pool', (
      tester,
    ) async {
      final pool = <String>{};
      for (final n in ['Ann', 'Bo', 'Cy', 'Di']) {
        pool.add((await person(n)).id);
      }
      for (final n in ['Ed', 'Flo', 'Gus']) {
        await person(n);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: FaceGameScreen(
            repository: repository,
            planner: FaceQuizPlanner(Random(3), DateTime.now),
            showDelay: false,
            pool: pool,
            pauseAfterRight: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      for (var turn = 0; turn < 4; turn++) {
        final shown = tester
            .widgetList<AnswerRow>(find.byType(AnswerRow))
            .map((row) => row.name)
            .toSet();
        expect(shown, {'Ann', 'Bo', 'Cy', 'Di'});
        final image = tester.widget<Image>(find.byType(Image)).image;
        final id = (image as FileImage).file.uri.pathSegments.last
            .split('.')
            .first;
        expect(pool, contains(id));
        final name = repository.stored[id]!.field(MemoryField.name);
        await tester.tap(find.text(name));
        await tester.pump();
        await tester.pump(Duration.zero);
        await tester.pump();
      }
      expect(find.textContaining('4 of 4 right first try'), findsOneWidget);
    });

    testWidgets('details: the dialog counts their details, and a pool '
        'too small says why', (tester) async {
      final services = testServices(repository);
      for (final n in ['Ann', 'Bo', 'Cy']) {
        final m = await repository.add(
          photoJpeg: [],
          capturedAt: DateTime(2026, 1, repository.stored.length + 1),
          place: 'Cafe',
        );
        await repository.save(
          m.withField('name', n).withDetails([
            Detail(id: '${m.id}-d', text: 'Likes $n', at: DateTime.utc(2026)),
          ]),
        );
      }
      await person('Di', detail: 'Tall');
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      services.listFilters.show([const PlaceFilter('Cafe')]);
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryListScreen(
            services: services,
            routeObserver: RouteObserver<ModalRoute<void>>(),
            onMeetSomeone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('3 people; 3 of their details to ask.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Play with the filtered list'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Needs 4 people and a detail to ask; this list has 3 people '
          'and 3 details.',
        ),
        findsOneWidget,
      );
    });
  });
}
