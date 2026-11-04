import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Under a person on a filtered list, small lines saying why they match:
/// for a date range, the details dated in it ("Wedding: 3 Jun 2010 - at
/// the lake") and the photos taken in it; for an anniversary range or a
/// tag, the anniversaries or tags that match; for "Details contain", each
/// matching detail with the words found in bold. Each reads as on the
/// person's card ([DetailSummary]), after its kind where that is not
/// plain. Every matching line shows.
class FilterMatchLines extends StatelessWidget {
  const FilterMatchLines({
    super.key,
    required this.memory,
    required this.filters,
    required this.nameOf,
  });

  final Memory memory;
  final List<FilterCondition> filters;

  /// The shown name of an active person (a relationship's), or null.
  final String? Function(String id) nameOf;

  /// The lines for [memory], as plain text with the spans to highlight.
  static List<({String text, List<(int, int)> bold})> linesFor(
    Memory memory,
    List<FilterCondition> filters,
    String? Function(String id) nameOf,
  ) {
    final lines = <({String text, List<(int, int)> bold})>[];
    // A detail matching two filters shows once: with its words in bold if
    // "Details contain" found it, so that filter goes first.
    final shown = <String>{};
    void plain(List<Detail> details) {
      for (final d in details) {
        if (!shown.add(d.id)) continue;
        lines.add((
          text: DetailSummary.kindHead(d) + DetailSummary.lineFor(d, nameOf),
          bold: const [],
        ));
      }
    }

    for (final filter in [
      ...filters.whereType<DetailsFilter>(),
      ...filters.where((f) => f is! DetailsFilter),
    ]) {
      switch (filter) {
        case DateRangeFilter():
          plain(filter.detailsIn(memory));
          for (final e in filter.encountersIn(memory)) {
            final day = DetailPrompt.date(e.capturedAt.toLocal());
            lines.add((text: 'Photo · $day', bold: const []));
          }
        case AnniversaryFilter():
          plain(filter.detailsIn(memory));
        case TagFilter():
          plain(filter.detailsIn(memory));
        case DetailsFilter():
          for (final d in filter.detailsIn(memory)) {
            if (!shown.add(d.id)) continue;
            // The kind is never searched, so never highlighted.
            final head = DetailSummary.kindHead(d);
            final rest = DetailSummary.lineFor(d, nameOf);
            lines.add((
              text: '$head$rest',
              bold: [
                for (final (a, b) in filter.spans(rest))
                  (a + head.length, b + head.length),
              ],
            ));
          }
        default:
          break;
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = linesFor(memory, filters, nameOf);
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final bold = TextStyle(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text.rich(
            TextSpan(children: _spans(line.text, line.bold, bold)),
            style: small,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  static List<TextSpan> _spans(
    String text,
    List<(int, int)> bold,
    TextStyle boldStyle,
  ) {
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in bold) {
      // Lower case can change a string's length; then skip the bold.
      if (start < at || end > text.length) continue;
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: boldStyle));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }
}
