import 'dart:io';

import 'package:flutter/material.dart';

import '../memories/memory_tile.dart';
import '../memories/progress_badge.dart';
import 'game_feedback.dart';
import 'quiz_result.dart';

/// The end of a quiz: the score, then a row per turn. A right answer shows
/// its progress pie; a miss shows the right answer kindly. When anything
/// became remembered this game, a banner says so first, with a star and a
/// chime, and those rows get a star too.
class QuizResultsView extends StatefulWidget {
  const QuizResultsView({
    super.key,
    required this.results,
    required this.threshold,
    required this.photoOf,
    required this.onDone,
    this.feedback,
  });

  final List<QuizResult> results;
  final int threshold;
  final File Function(QuizResult result) photoOf;
  final VoidCallback onDone;

  /// Chimes once for the banner; null is silent (tests).
  final GameFeedback? feedback;

  /// The banner's words for what became remembered: by name for one.
  static String bannerText(List<QuizResult> crossed) => crossed.length == 1
      ? 'You remember ${MemoryTile.nameOf(crossed.single.person)} now!'
      : 'You remember ${crossed.length} more now!';

  static const missText = "You'll see them again soon.";

  @override
  State<QuizResultsView> createState() => _QuizResultsViewState();
}

class _QuizResultsViewState extends State<QuizResultsView> {
  late final List<QuizResult> _crossed = [
    for (final r in widget.results)
      if (r.crossed(widget.threshold)) r,
  ];

  @override
  void initState() {
    super.initState();
    if (_crossed.isNotEmpty) widget.feedback?.right();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final right = widget.results.where((r) => r.rightFirstTry).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_crossed.isNotEmpty) _banner(context),
              Semantics(
                liveRegion: true,
                child: Text(
                  '$right of ${widget.results.length} right first try',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              for (final result in widget.results) _row(context, result),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: widget.onDone,
            child: const Text('Back to list'),
          ),
        ),
      ],
    );
  }

  Widget _banner(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: ProgressBadge.rememberedColor,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  QuizResultsView.bannerText(_crossed),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, QuizResult result) {
    final theme = Theme.of(context);
    final name = MemoryTile.nameOf(result.person);
    final detail = result.detailText;
    final crossed = _crossed.contains(result);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          widget.photoOf(result),
          width: 40,
          height: 50,
          fit: BoxFit.cover,
          cacheWidth: 120,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) =>
              const SizedBox(width: 40, child: Icon(Icons.person)),
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          ?detail,
          if (!result.rightFirstTry) QuizResultsView.missText,
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (crossed)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.star,
                color: Colors.amber,
                semanticLabel: 'Now remembered',
              ),
            ),
          if (result.rightFirstTry)
            ProgressBadge(
              points: result.pointsAfter,
              threshold: widget.threshold,
            )
          else
            Icon(
              Icons.close,
              semanticLabel: 'Missed',
              color: theme.colorScheme.error,
            ),
        ],
      ),
    );
  }
}
