import 'dart:io';

import 'package:flutter/material.dart';

import '../app/bottom_action_bar.dart';
import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
import '../memories/memory_tile.dart';
import '../memories/progress_badge.dart';
import 'game_feedback.dart';
import 'quiz_result.dart';

/// The end of a quiz: the score, then a row per turn. A right answer shows
/// its progress bar; a miss shows the right answer kindly. When anything
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
    final total = widget.results.length;
    // The missed first: they are the ones to look at again.
    final missed = [
      for (final r in widget.results)
        if (!r.rightFirstTry) r,
    ];
    final got = [
      for (final r in widget.results)
        if (r.rightFirstTry) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (_crossed.isNotEmpty) _banner(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RememberemTheme.gutter,
                  16,
                  RememberemTheme.gutter,
                  8,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '$right of $total right first try',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : right / total,
                  minHeight: 6,
                  // Primary on its own tint: gold is about 1.3:1 on it.
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.16,
                  ),
                ),
              ),
              if (missed.isNotEmpty) ...[
                SectionHeader(
                  title: 'See again soon',
                  count: missed.length,
                  tinted: false,
                ),
                for (final result in missed) _row(context, result),
              ],
              if (got.isNotEmpty) ...[
                SectionHeader(
                  title: 'Got it',
                  count: got.length,
                  tinted: false,
                ),
                for (final result in got) _row(context, result),
              ],
            ],
          ),
        ),
        BottomActionBar(
          // In the middle, which is bounded, so large text wraps in the
          // button instead of running off the screen.
          middle: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              style: BottomActionBar.goldStyle,
              onPressed: widget.onDone,
              child: const Text('Back to list'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _banner(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: RememberemTheme.rememberedGreen,
      margin: const EdgeInsets.fromLTRB(
        RememberemTheme.gutter,
        16,
        RememberemTheme.gutter,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 40),
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
    final text = theme.textTheme;
    final name = MemoryTile.nameOf(result.person);
    final detail = result.detailText;
    final crossed = _crossed.contains(result);
    final subtitle = [
      ?detail,
      if (!result.rightFirstTry) QuizResultsView.missText,
    ].join('\n');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: RememberemTheme.gutter,
          ),
          horizontalTitleGap: RememberemTheme.thumbGap,
          minLeadingWidth: RememberemTheme.thumbRow.width,
          minTileHeight: 58,
          minVerticalPadding: 12,
          titleTextStyle: text.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          subtitleTextStyle: text.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          // The name beside it already says whose photo this is.
          leading: PortraitThumb(photo: widget.photoOf(result)),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (crossed)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.star_rounded,
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
                  Icons.close_rounded,
                  semanticLabel: 'Missed',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: RememberemTheme.rowTextInset,
          color: RememberemTheme.rule(theme),
        ),
      ],
    );
  }
}
