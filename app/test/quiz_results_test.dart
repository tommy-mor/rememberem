import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:rememberem/src/memories/progress_badge.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem/src/practice/quiz_result.dart';
import 'package:rememberem/src/practice/quiz_results_view.dart';
import 'package:rememberem/src/settings/app_settings_controller.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_game_feedback.dart';
import 'fakes/fake_memory_repository.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  Memory named(String name, {int points = 0}) => Memory(
    id: name.toLowerCase(),
    encounters: [
      Encounter(
        photoFileName: '${name.toLowerCase()}.jpg',
        capturedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
    fields: {'name': name},
    points: points,
  );

  group('QuizResult', () {
    test('right first try adds a point, a miss resets, an unsaved answer '
        'changes nothing', () {
      final ann = named('Ann', points: 4);
      expect(
        QuizResult.answered(
          person: ann,
          rightFirstTry: true,
          saved: true,
        ).pointsAfter,
        5,
      );
      expect(
        QuizResult.answered(
          person: ann,
          rightFirstTry: false,
          saved: true,
        ).pointsAfter,
        0,
      );
      expect(
        QuizResult.answered(
          person: ann,
          rightFirstTry: true,
          saved: false,
        ).pointsAfter,
        4,
      );
    });

    test('a detail answer counts the detail\'s points', () {
      final detail = Detail(
        id: 'd',
        text: 'Tall',
        at: DateTime.utc(2026),
      ).withScore(9, null);
      final r = QuizResult.answered(
        person: named('Ann'),
        detail: detail,
        rightFirstTry: true,
        saved: true,
      );
      expect((r.pointsBefore, r.pointsAfter), (9, 10));
      expect(r.crossed(10), isTrue);
    });

    test('crossed only when this answer reached the threshold', () {
      QuizResult r(int before, int after) => QuizResult(
        person: named('Ann'),
        rightFirstTry: true,
        pointsBefore: before,
        pointsAfter: after,
      );
      expect(r(9, 10).crossed(10), isTrue);
      expect(r(10, 11).crossed(10), isFalse);
      expect(r(8, 9).crossed(10), isFalse);
    });
  });

  group('QuizResultsView', () {
    Future<FakeGameFeedback> show(
      WidgetTester tester,
      List<QuizResult> results,
    ) async {
      final feedback = FakeGameFeedback();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizResultsView(
              results: results,
              threshold: 5,
              photoOf: (_) => File('missing.jpg'),
              feedback: feedback,
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      return feedback;
    }

    testWidgets('a crossing gets a banner by name, a star and one chime', (
      tester,
    ) async {
      final feedback = await show(tester, [
        QuizResult(
          person: named('Ann'),
          rightFirstTry: true,
          pointsBefore: 4,
          pointsAfter: 5,
        ),
        QuizResult(
          person: named('Bo'),
          rightFirstTry: false,
          pointsBefore: 3,
          pointsAfter: 0,
        ),
      ]);

      expect(find.text('You remember Ann now!'), findsOneWidget);
      expect(find.text('1 of 2 right first try'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(2)); // banner and row
      expect(feedback.given, ['right']);
      // A miss shows the person kindly, not an emptied pie.
      expect(find.text(QuizResultsView.missText), findsOneWidget);
      expect(find.byType(ProgressBadge), findsOneWidget);
    });

    testWidgets('nothing crossed: no banner, no star, no chime', (
      tester,
    ) async {
      final feedback = await show(tester, [
        QuizResult(
          person: named('Ann'),
          rightFirstTry: true,
          pointsBefore: 1,
          pointsAfter: 2,
        ),
      ]);

      expect(find.textContaining('You remember'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(feedback.given, isEmpty);
    });

    test('several crossings are counted', () {
      final rs = [
        for (final n in ['Ann', 'Bo', 'Cy'])
          QuizResult(
            person: named(n),
            rightFirstTry: true,
            pointsBefore: 4,
            pointsAfter: 5,
          ),
      ];
      expect(QuizResultsView.bannerText(rs), 'You remember 3 more now!');
    });
  });

  testWidgets('a face game ends with results using the threshold from '
      'Settings', (tester) async {
    final repository = FakeMemoryRepository();
    for (final name in ['Ann', 'Bo', 'Cy', 'Di']) {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 1, repository.stored.length + 1),
      );
      await repository.save(m.withField('name', name));
    }
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FaceGameScreen(
          repository: repository,
          planner: FaceQuizPlanner(Random(1), () => now),
          clock: () => now,
          turns: 1,
          pauseAfterRight: Duration.zero,
          settings: AppSettingsController(
            const AppSettings(rememberedThreshold: 1),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final image = tester.widget<Image>(find.byType(Image)).image as FileImage;
    final id = image.file.uri.pathSegments.last.split('.').first;
    final name = repository.stored[id]!.field(MemoryField.name);

    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(find.text('1 of 1 right first try'), findsOneWidget);
    expect(find.text('You remember $name now!'), findsOneWidget);
  });

  testWidgets('the list labels its quiz buttons', (tester) async {
    expect(MemoryListScreen.quizzesLabel, 'Quizzes to help you remember...');
  });

  test('the default threshold is 10, and a stored one is kept', () {
    expect(RememberedCount.defaultThreshold, 10);
    expect(const AppSettings().rememberedThreshold, 10);
    expect(
      AppSettings.fromJson({'rememberedThreshold': 5}).rememberedThreshold,
      5,
    );
    expect(AppSettings.rememberedThresholdRange.max, greaterThan(10));
  });
}
