import 'dart:math';

import 'detail.dart';
import 'memory.dart';
import 'practice_weight.dart';

/// A detail to practise and the person it is about.
typedef DetailPair = ({Memory person, Detail detail});

/// Chooses details and photo choices for the details practice game.
class DetailQuizPlanner {
  DetailQuizPlanner(this._random, this._clock);

  final Random _random;
  final DateTime Function() _clock;

  /// How many people (photos) each turn offers.
  static const choiceCount = 4;

  /// Every non-blank detail of [active] people, with its owner.
  List<DetailPair> eligible(List<Memory> active) => [
        for (final person in active)
          for (final detail in person.details)
            if (detail.text.trim().isNotEmpty) (person: person, detail: detail),
      ];

  /// Enough to play: [choiceCount] people and at least one detail. The one
  /// definition used by the list button and the game.
  bool canPlay(List<Memory> active) =>
      active.length >= choiceCount && eligible(active).isNotEmpty;

  /// A weighted random pick over details (not people, so a stale detail of
  /// a well-known person still comes up), never a detail in [asked] (ids
  /// already quizzed this game). Null once every detail has been asked.
  DetailPair? pickNext(List<DetailPair> pairs, {Set<String> asked = const {}}) {
    final pool = [
      for (final p in pairs)
        if (!asked.contains(p.detail.id)) p,
    ];
    if (pool.isEmpty) return null;
    final now = _clock();
    final weights = [
      for (final p in pool)
        practiceWeight(p.detail.points, p.detail.lastCorrectDate, now),
    ];
    var roll = _random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    for (final (i, weight) in weights.indexed) {
      roll -= weight;
      if (roll < 0) return pool[i];
    }
    return pool.last;
  }

  /// [person] plus three other people, shuffled. Distinct by id, so two
  /// people with the same name are two different cards.
  List<Memory> choicesFor(Memory person, List<Memory> active) {
    final others = [
      for (final m in active)
        if (m.id != person.id) m,
    ]..shuffle(_random);
    return [person, ...others.take(choiceCount - 1)]..shuffle(_random);
  }
}
