import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import 'detail_game_screen.dart';
import 'face_game_screen.dart';

/// Builds a practice game as Fred's settings say. Every way into a game
/// (the list's buttons, a reminder) goes through here.
class PracticeScreens {
  const PracticeScreens._();

  static Widget build(PracticeGame game, AppServices services) {
    final settings = services.settings.value;
    return switch (game) {
      PracticeGame.faces => FaceGameScreen(
        repository: services.repository,
        planner: FaceQuizPlanner(Random(), DateTime.now),
        reveal: settings.reveal,
        turns: settings.gameTurns,
        feedback: services.feedback,
      ),
      PracticeGame.details => DetailGameScreen(
        repository: services.repository,
        planner: DetailQuizPlanner(Random(), DateTime.now),
        reveal: settings.reveal,
        turns: settings.gameTurns,
        feedback: services.feedback,
      ),
    };
  }
}
