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

  static String nameOf(Memory memory) {
    final name = memory.field(MemoryField.name);
    return name.isEmpty ? 'Unnamed' : name;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
