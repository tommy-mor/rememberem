import 'dart:math';

import 'detail_quiz_planner.dart';
import 'face_quiz_planner.dart';
import 'memory.dart';
import 'practice_game.dart';

/// Which game a reminder should open, decided when it is tapped.
class ReminderTarget {
  const ReminderTarget._();

  /// [requested] if it can be played, else the first playable game (faces,
  /// then details), else null. [active] must exclude trashed people.
  static PracticeGame? resolve(List<Memory> active, PracticeGame? requested) {
    // Only canPlay is used, which needs neither randomness nor a clock.
    final faces = FaceQuizPlanner(Random(0), DateTime.now).canPlay(active);
    final details = DetailQuizPlanner(Random(0), DateTime.now).canPlay(active);
    bool playable(PracticeGame game) => switch (game) {
          PracticeGame.faces => faces,
          PracticeGame.details => details,
        };
    if (requested != null && playable(requested)) return requested;
    for (final game in PracticeGame.values) {
      if (playable(game)) return game;
    }
    return null;
  }
}
