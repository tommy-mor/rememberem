import 'dart:math';

import 'memory.dart';
import 'memory_field.dart';
import 'practice_weight.dart';

/// Chooses faces and name choices for the face practice game.
class FaceQuizPlanner {
  FaceQuizPlanner(this._random, this._clock);

  final Random _random;
  final DateTime Function() _clock;

  /// How many distinct names a game needs, for four different choices.
  static const choiceCount = 4;

  /// People who can be quizzed: those with a name. People sharing a name
  /// stay quizzable (they share one button).
  List<Memory> eligible(List<Memory> active) => [
        for (final m in active)
          if (_name(m).isNotEmpty) m,
      ];

  /// The number of different names among [active]; a game needs
  /// [choiceCount]. The one definition of "enough people to play".
  int distinctNameCount(List<Memory> active) =>
      {for (final m in eligible(active)) _name(m)}.length;

  bool canPlay(List<Memory> active) => distinctNameCount(active) >= choiceCount;

  /// A weighted random pick, favouring few points and long-ago (or never)
  /// right answers. Never [previousId] again when there is a choice.
  Memory pickNext(List<Memory> eligible, {String? previousId}) {
    final pool = eligible.length > 1
        ? [
            for (final m in eligible)
              if (m.id != previousId) m
          ]
        : eligible;
    final now = _clock();
    final weights = [
      for (final m in pool) practiceWeight(m.points, m.lastCorrectDate, now),
    ];
    var roll = _random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (final (i, weight) in weights.indexed) {
      roll -= weight;
      if (roll < 0) return pool[i];
    }
    return pool.last;
  }

  /// [person]'s name plus three other different names, shuffled. Any
  /// button showing that name is right.
  List<String> choicesFor(Memory person, List<Memory> eligible) {
    final answer = _name(person);
    final decoys = {
      for (final m in eligible)
        if (_name(m) != answer) _name(m),
    }.toList()
      ..shuffle(_random);
    return [answer, ...decoys.take(choiceCount - 1)]..shuffle(_random);
  }

  static String _name(Memory m) => m.field(MemoryField.name).trim();
}
