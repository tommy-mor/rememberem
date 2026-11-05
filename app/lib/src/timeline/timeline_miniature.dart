import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../memories/memory_tile.dart';

/// A small photo of a person with their first name under it, for the
/// timeline. A screen reader hears the full name and a button.
class TimelineMiniature extends StatelessWidget {
  const TimelineMiniature({
    super.key,
    required this.memory,
    required this.photo,
    required this.onOpen,
  });

  /// The cell's width; the photo is 44 dp wide inside it.
  static const cellWidth = 52.0;

  final Memory memory;
  final File photo;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = MemoryTile.nameOf(memory);
    return Semantics(
      container: true,
      button: true,
      label: name,
      onTap: onOpen,
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: cellWidth,
          child: Column(
            children: [
              PortraitThumb(photo: photo, size: RememberemTheme.thumbTimeline),
              const SizedBox(height: 2),
              Text(
                name.trim().split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
