import 'dart:math';

import 'detail.dart';
import 'detail_kind.dart';
import 'detail_prompt.dart';
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

  /// The details that can be asked, with their owners: non-blank, complete
  /// (a relationship's other person is active and not the owner; an
  /// anniversary has its type and date), and read differently from every
  /// other active person's details, so exactly one choice is ever right.
  List<DetailPair> eligible(List<Memory> active) {
    final prompt = promptFor(active);
    final owners = <String, Set<String>>{};
    for (final person in active) {
      for (final detail in person.details) {
        owners
            .putIfAbsent(prompt(detail).equivalenceKey, () => {})
            .add(person.id);
      }
    }
    final ids = {for (final m in active) m.id};
    return [
      for (final person in active)
        for (final detail in person.details)
          if (detail.text.trim().isNotEmpty &&
              _complete(detail, person.id, ids) &&
              owners[prompt(detail).equivalenceKey]!.length == 1)
            (person: person, detail: detail),
    ];
  }

  /// How each detail reads among [active] people.
  static DetailPrompt Function(Detail) promptFor(List<Memory> active) {
    final names = {for (final m in active) m.id: m.displayName};
    return (detail) => DetailPrompt(detail, (id) => names[id]);
  }

  static bool _complete(Detail d, String ownerId, Set<String> activeIds) =>
      switch (d.kind) {
        DetailKind.relationship => d.targetId != null &&
            d.targetId != ownerId &&
            activeIds.contains(d.targetId),
        DetailKind.anniversary =>
          (d.label?.trim() ?? '').isNotEmpty && d.eventDate != null,
        DetailKind.fact || DetailKind.happening => true,
        // Many people share a tag, so a question would have several right
        // answers.
        DetailKind.tag => false,
      };

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
