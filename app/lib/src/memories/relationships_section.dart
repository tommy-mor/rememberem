import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Everyone this person is related to, both ways: their own relationships
/// ("Brother") and those on other people that point here ("Bo is their
/// brother"). Tapping one opens that person. Hidden when there are none.
class RelationshipsSection extends StatelessWidget {
  const RelationshipsSection({
    super.key,
    required this.person,
    required this.people,
    required this.photoOf,
    required this.onOpen,
  });

  /// This person as edited now.
  final Memory person;

  /// Everyone; only active people are shown.
  final List<Memory> people;
  final File Function(Memory person) photoOf;
  final ValueChanged<Memory> onOpen;

  @override
  Widget build(BuildContext context) {
    final links = RelationshipIndex.of(person, people);
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Relationships', style: Theme.of(context).textTheme.titleSmall),
        for (final link in links)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                photoOf(link.person),
                width: 32,
                height: 40,
                fit: BoxFit.cover,
                cacheWidth: 100,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 32, child: Icon(Icons.person)),
              ),
            ),
            title: Text(link.person.displayName),
            subtitle: Text(_describe(link)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpen(link.person),
          ),
      ],
    );
  }

  String _describe(RelationshipLink link) {
    final label = link.label;
    if (link.outgoing) {
      return label.isEmpty
          ? 'Relationship'
          : label[0].toUpperCase() + label.substring(1);
    }
    final name = person.displayName;
    return label.isEmpty ? 'Related to $name' : '$name is their $label';
  }
}
