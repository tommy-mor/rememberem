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
  });

  final Memory memory;
  final File photo;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// What to call someone whose name is blank (nothing is stored).
  static const unknownName = Memory.unknownName;

  static String nameOf(Memory memory) => memory.displayName;

  /// Practice points for [memory]: its face's plus its details'.
  static int pointsOf(Memory memory) =>
      memory.points + memory.details.fold(0, (sum, d) => sum + d.points);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Tight: lines close together, people close together.
    return ListTile(
      visualDensity: const VisualDensity(vertical: -4),
      minVerticalPadding: 3,
      minTileHeight: 0,
      titleTextStyle: text.bodyLarge?.copyWith(height: 1.25),
      subtitleTextStyle: text.bodyMedium?.copyWith(
        height: 1.15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      leading: CircleAvatar(
        backgroundImage: FileImage(photo),
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
  }
}
