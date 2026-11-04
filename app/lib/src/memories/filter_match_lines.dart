import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Under a person on a filtered list, small lines saying why they match:
/// for a date range, the details dated in it ("Anniversary · Wedding ·
/// every 3 Jun (2010)") and the photos taken in it; for "Details contain",
/// each matching detail with the words found in bold. At most [most]
/// lines, then "+N more".
class FilterMatchLines extends StatelessWidget {
  const FilterMatchLines({
    super.key,
    required this.memory,
    required this.filters,
  });

  final Memory memory;
  final List<FilterCondition> filters;

  static const most = 3;

  /// The lines for [memory], as plain text with the spans to highlight.
  static List<({String text, List<(int, int)> bold})> linesFor(
    Memory memory,
    List<FilterCondition> filters,
  ) {
    final lines = <({String text, List<(int, int)> bold})>[];
    for (final filter in filters) {
      switch (filter) {
        case DateRangeFilter():
          for (final d in filter.detailsIn(memory)) {
            lines.add((text: _dated(d), bold: const []));
          }
          for (final e in filter.encountersIn(memory)) {
            final day = DetailPrompt.date(e.capturedAt.toLocal());
            lines.add((text: 'Photo · $day', bold: const []));
          }
        case DetailsFilter():
          for (final d in filter.detailsIn(memory)) {
            // Only the type and the words are searched, so only they are
            // highlighted, never the kind.
            final head = '${d.kind.label} · ';
            final label = _capitalised(d.label?.trim() ?? '');
            final rest = [
              label,
              d.text.trim(),
            ].where((s) => s.isNotEmpty).join(': ');
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

  /// A dated detail: its kind, type and date. An anniversary says it
  /// comes every year, so a match in another year makes sense.
  static String _dated(Detail d) {
    final label = _capitalised(d.label?.trim() ?? '');
    final String when;
    if (d.kind == DetailKind.anniversary && d.eventDate != null) {
      final first = DetailPrompt.date(d.eventDate!);
      final dayMonth = first.substring(0, first.lastIndexOf(' '));
      when = 'every $dayMonth (${d.eventDate!.year})';
    } else if (d.kind == DetailKind.happening) {
      when = DetailPrompt.date(d.at.toLocal());
    } else {
      when = d.eventDate == null ? '' : DetailPrompt.date(d.eventDate!);
    }
    return [d.kind.label, label, when].where((s) => s.isNotEmpty).join(' · ');
  }

  static String _capitalised(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final lines = linesFor(memory, filters);
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
        for (final line in lines.take(most))
          Text.rich(
            TextSpan(children: _spans(line.text, line.bold, bold)),
            style: small,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        if (lines.length > most)
          Text('+${lines.length - most} more', style: small),
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
