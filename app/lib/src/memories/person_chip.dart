import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'memory_tile.dart';

/// A person's round photo and name; tapping opens them.
class PersonChip extends StatelessWidget {
  const PersonChip({
    super.key,
    required this.memory,
    required this.repository,
    required this.onTap,
  });

  final Memory memory;
  final MemoryRepository repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: CircleAvatar(
        backgroundImage: FileImage(repository.photoFile(memory)),
        onBackgroundImageError: (_, _) {},
      ),
      label: Text(MemoryTile.nameOf(memory)),
      onPressed: onTap,
    );
  }
}
