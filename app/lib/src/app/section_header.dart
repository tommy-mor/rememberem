import 'package:flutter/material.dart';

import 'rememberem_theme.dart';

/// A group's heading: its title as a capitalised overline, an optional
/// count, and an optional [trailing] widget such as an add button (give it
/// its own 48 dp tap area). [tinted] sets it on a strip a shade off the
/// page; untinted it is just text, as over a list group.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.tinted = true,
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = count == null
        ? title.toUpperCase()
        : '${title.toUpperCase()}  $count';
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      color: tinted
          ? RememberemTheme.shade(theme, theme.colorScheme.surface)
          : null,
      padding: EdgeInsetsDirectional.only(
        start: RememberemTheme.gutter,
        end: trailing == null ? RememberemTheme.gutter : 0,
        top: tinted ? 0 : 14,
        bottom: tinted ? 0 : 2,
      ),
      child: Row(
        children: [
          Expanded(
            // Upper case to look at, the original case to a screen reader.
            child: Semantics(
              header: true,
              label: count == null ? title : '$title, $count',
              excludeSemantics: true,
              child: Text(text, style: RememberemTheme.overline(theme)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
