import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

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
    final text = Theme.of(context).textTheme;
    // Tight: lines close together, people close together.
    final tile = ListTile(
      visualDensity: const VisualDensity(vertical: -4),
      minVerticalPadding: 3,
      minTileHeight: 0,
      titleTextStyle: text.bodyLarge?.copyWith(height: 1.25),
      subtitleTextStyle: text.bodyMedium?.copyWith(
        height: 1.15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      leading: CircleAvatar(
        backgroundImage: ResizeImage(FileImage(photo), width: 120),
        onBackgroundImageError: (_, _) {},
      ),
      title: Text(nameOf(memory)),
      subtitle: Text(
        [
          memory.field(MemoryField.place),
          memory.field(MemoryField.meeting),
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: trailing,
      onTap: onTap,
    );
    final below = this.below;
    if (below == null) return tile;
    // One stop for a screen reader: the person, then why they match.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile,
            // Past the photo: 16 padding, a 40 avatar, 16 gap.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 6),
              child: below,
            ),
          ],
        ),
      ),
    );
  }
}
