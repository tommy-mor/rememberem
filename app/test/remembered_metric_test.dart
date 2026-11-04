import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/memories/progress_badge.dart';
import 'package:rememberem/src/memories/remembered_label.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

class _HeldList extends FakeMemoryRepository {
  final hold = Completer<void>();

  @override
  Future<List<Memory>> all() async {
    await hold.future;
    return super.all();
  }
}

void main() {
  late FakeMemoryRepository repository;
  late GlobalKey<NavigatorState> navigator;

  Future<Memory> person(
    String name, {
    int points = 0,
    int detailPoints = 0,
  }) async {
    final m = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 1, repository.stored.length + 1),
    );
    final saved = m
        .withField('name', name)
        .withDetails([
          Detail(
            id: '${m.id}-d',
            text: 'Tall',
            at: DateTime.utc(2026),
            points: detailPoints,
          ),
        ])
        .withScore(points, null);
    // Scores are set straight on the store: save() keeps stored scores.
    repository.stored[m.id] = saved;
    return saved;
  }

  Future<void> showList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    navigator = GlobalKey<NavigatorState>();
    final observer = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
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
            // Set, not the default, so these tests keep their meaning.
            settings: AppSettingsController(
              const AppSettings(rememberedThreshold: 5),
            ),
          ),
          routeObserver: observer,
          onMeetSomeone: () {},
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => repository = FakeMemoryRepository());

  group('label', () {
    Future<void> label(WidgetTester tester, RememberedCount count) =>
        tester.pumpWidget(MaterialApp(home: RememberedLabel(count)));

    testWidgets('says 1 face and 1 detail in the singular', (tester) async {
      await label(tester, const RememberedCount(1, 1));
      expect(find.text('Remembered: 1 face · 1 detail'), findsOneWidget);
    });

    testWidgets('plural, and zero details as a number', (tester) async {
      await label(tester, const RememberedCount(2, 0));
      expect(find.text('Remembered: 2 faces · 0 details'), findsOneWidget);
    });

    testWidgets('nothing yet invites practice, never "0 faces"', (
      tester,
    ) async {
      await label(tester, const RememberedCount(0, 0));
      expect(
        find.text('Remembered: nothing yet, practice to start'),
        findsOneWidget,
      );
      expect(find.textContaining('0 faces'), findsNothing);
    });
  });

  testWidgets('the list shows exact counts from the scores', (tester) async {
    await person('Ann', points: 5, detailPoints: 5);
    await person('Bo', points: 4, detailPoints: 6);
    await person('Cy', points: 9);
    await showList(tester);

    expect(find.text('Remembered: 2 faces · 2 details'), findsOneWidget);
    expect(find.text('Meet someone'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Faces'), findsOneWidget);
  });

  testWidgets('a face with points shows a pie of its progress, green once '
      'remembered; detail points alone show none', (tester) async {
    await person('Ann', points: 5);
    await person('Bo', points: 2);
    await person('Cy', detailPoints: 3);
    await showList(tester);

    ProgressBadge? badgeOf(String name) {
      final found = find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.byType(ProgressBadge),
      );
      return found.evaluate().isEmpty
          ? null
          : tester.widget<ProgressBadge>(found);
    }

    expect(badgeOf('Ann')!.remembered, isTrue); // threshold 5
    expect(find.byTooltip('Name remembered'), findsOneWidget);
    expect(badgeOf('Bo')!.remembered, isFalse);
    expect(find.byTooltip('2 of 5 right'), findsOneWidget);
    expect(badgeOf('Cy'), isNull);
    expect(find.text('5'), findsNothing); // no number any more
  });

  testWidgets('coming back from a game shows new points', (tester) async {
    final ann = await person('Ann', points: 4);
    await showList(tester);
    // Nothing remembered yet: the line is left out.
    expect(find.byType(RememberedLabel), findsNothing);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    await repository.recordAnswer(
      ann.id,
      correctFirstTry: true,
      at: DateTime.utc(2026),
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Remembered: 1 face · 0 details'), findsOneWidget);
    expect(repository.saves, isEmpty); // the list only reads
  });

  testWidgets('nothing shows while loading or when there is no one', (
    tester,
  ) async {
    repository = _HeldList();
    await person('Ann', points: 9);
    await showList(tester);
    expect(find.byType(RememberedLabel), findsNothing);
    (repository as _HeldList).hold.complete();
    await tester.pump();
    expect(find.byType(RememberedLabel), findsOneWidget);

    repository = FakeMemoryRepository();
    await showList(tester);
    expect(find.byType(RememberedLabel), findsNothing);
  });
}
