import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';

/// One person in a list: photo, name, and where and when you met.
class MemoryTile extends StatelessWidget {
  const MemoryTile({
    super.key,
    required this.memory,
    required this.photo,
    this.trailing,
    this.onTap,
    this.below,
  });

  final Memory memory;
  final File photo;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Shown under the name and place, lined up with them (why a person
  /// matches a filter).
  final Widget? below;

  /// What to call someone whose name is blank (nothing is stored).
  static const unknownName = Memory.unknownName;

  static String nameOf(Memory memory) => memory.displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final tile = ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: RememberemTheme.gutter,
      ),
      horizontalTitleGap: RememberemTheme.thumbGap,
      minLeadingWidth: RememberemTheme.thumbRow.width,
      minTileHeight: 58,
      // A ListTile with a subtitle sizes itself to its text and ignores
      // minTileHeight, so this padding is what makes a row 58 dp.
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
      leading: PortraitThumb(photo: photo),
      title: Text(nameOf(memory)),
      subtitle: Text(
        [
          memory.field(MemoryField.place),
          memory.field(MemoryField.meeting),
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
      onTap: onTap,
    );
    final below = this.below;
    // Under the text, not under the photo.
    final rule = Divider(
      height: 1,
      thickness: 1,
      indent: RememberemTheme.rowTextInset,
      color: RememberemTheme.rule(theme),
    );
    if (below == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [tile, rule]);
    }
    // One stop for a screen reader: the person, then why they match.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile,
                // Past the photo: the gutter, the photo, the gap.
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    RememberemTheme.rowTextInset,
                    0,
                    RememberemTheme.gutter,
                    6,
                  ),
                  child: below,
                ),
              ],
            ),
          ),
        ),
        rule,
      ],
    );
  }
}
