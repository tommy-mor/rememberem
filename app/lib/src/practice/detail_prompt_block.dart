import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// A detail as the quiz asks about it: a small outlined chip with its kind
/// beside the [question], then the words themselves at 21 sp, three lines
/// at most. Text too long for three lines at 21 sp shrinks to 19 sp before
/// it is cut off with an ellipsis. With [announce], a screen reader reads
/// the words out when they appear.
class DetailPromptBlock extends StatelessWidget {
  const DetailPromptBlock({
    super.key,
    required this.prompt,
    required this.question,
    this.announce = false,
  });

  final DetailPrompt prompt;

  /// "Who is this about?", or how the last answer went.
  final String question;
  final bool announce;

  static const _maxLines = 3;

  TextStyle _style(double size) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.25);

  double _sizeFor(BuildContext context, double width) {
    final painter = TextPainter(
      text: TextSpan(text: prompt.full, style: _style(21)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: _maxLines,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits ? 21 : 19;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: muted),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Semantics(
                label: prompt.caption,
                excludeSemantics: true,
                child: Text(
                  prompt.caption.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(question, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => Semantics(
            liveRegion: announce,
            child: Text(
              prompt.full,
              textAlign: TextAlign.start,
              maxLines: _maxLines,
              overflow: TextOverflow.ellipsis,
              style: _style(_sizeFor(context, constraints.maxWidth)),
            ),
          ),
        ),
      ],
    );
  }
}
