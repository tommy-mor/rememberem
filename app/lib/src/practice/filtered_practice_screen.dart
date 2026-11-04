import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_routes.dart';
import '../app/app_services.dart';
import '../memories/filter_kind.dart';
import 'practice_screens.dart';

/// Before a game starts on a filtered list: how the list is filtered, how
/// many people and questions that leaves, and a choice to play with the
/// filtered list (the default) or with everyone.
class FilteredPracticeScreen extends StatelessWidget {
  const FilteredPracticeScreen({
    super.key,
    required this.game,
    required this.services,
    required this.filters,
    required this.filtered,
  });

  final PracticeGame game;
  final AppServices services;

  /// The filters that narrow the list.
  final List<FilterCondition> filters;

  /// The people the filters leave.
  final List<Memory> filtered;

  /// How many questions [people] gives [game]: named faces, or details.
  static int questions(PracticeGame game, List<Memory> people) =>
      switch (game) {
        PracticeGame.faces => FaceQuizPlanner(
          Random(),
          DateTime.now,
        ).eligible(people).length,
        PracticeGame.details => DetailQuizPlanner(
          Random(),
          DateTime.now,
        ).eligible(people).length,
      };

  /// Why [people] cannot play [game], or null if they can.
  static String? cannotPlay(PracticeGame game, List<Memory> people) {
    switch (game) {
      case PracticeGame.faces:
        final planner = FaceQuizPlanner(Random(), DateTime.now);
        if (planner.canPlay(people)) return null;
        final names = planner.distinctNameCount(people);
        return 'Needs ${FaceQuizPlanner.choiceCount} different names; this '
            'list has $names.';
      case PracticeGame.details:
        final planner = DetailQuizPlanner(Random(), DateTime.now);
        if (planner.canPlay(people)) return null;
        final details = planner.eligible(people).length;
        return 'Needs ${DetailQuizPlanner.choiceCount} people and a detail to '
            'ask; this list has '
            '${people.length} ${people.length == 1 ? 'person' : 'people'} '
            'and $details ${details == 1 ? 'detail' : 'details'}.';
    }
  }

  void _play(BuildContext context, Set<String>? pool) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.practice),
        builder: (_) => PracticeScreens.build(game, services, pool: pool),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = filtered.length;
    final asked = questions(game, filtered);
    final problem = cannotPlay(game, filtered);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          game == PracticeGame.faces ? 'Practice faces' : 'Practice details',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('The list is filtered:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final f in filters)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(FilterKind.describe(f)),
              ),
            const SizedBox(height: 16),
            Text(
              game == PracticeGame.faces
                  ? '${count == 1 ? '1 person' : '$count people'}, '
                        '$asked ${asked == 1 ? 'face' : 'faces'} to ask.'
                  // Every detail of these people, not only matching ones.
                  : '${count == 1 ? '1 person' : '$count people'}; '
                        '$asked of their '
                        '${asked == 1 ? 'detail' : 'details'} to ask.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: problem != null
                  ? null
                  : () => _play(context, {for (final m in filtered) m.id}),
              child: const Text('Play with the filtered list'),
            ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(problem, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _play(context, null),
              child: const Text('Play with everyone'),
            ),
          ],
        ),
      ),
    );
  }
}
