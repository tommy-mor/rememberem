import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/memory_tile.dart';

/// A small photo of a person with their first name, for the timeline.
class TimelineMiniature extends StatelessWidget {
  const TimelineMiniature({
    super.key,
    required this.memory,
    required this.photo,
    required this.recorded,
    required this.onOpen,
  });

  final Memory memory;
  final File photo;

  /// Shown only because they were recorded that day (no details yet).
  final bool recorded;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                photo,
                width: 64,
                height: 80,
                fit: BoxFit.cover,
                cacheWidth: 160,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 64,
                  height: 80,
                  child: Icon(Icons.person),
                ),
              ),
            ),
            Text(
              MemoryTile.nameOf(memory).trim().split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
            if (recorded)
              Text(
                'recorded',
                style: small?.copyWith(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}
