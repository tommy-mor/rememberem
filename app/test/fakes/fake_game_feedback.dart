import 'package:rememberem/src/practice/game_feedback.dart';

/// Records the feedback a game gives.
class FakeGameFeedback implements GameFeedback {
  final List<String> given = [];

  @override
  void right() => given.add('right');

  @override
  void wrong() => given.add('wrong');
}
