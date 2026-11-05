import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';

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
        SectionHeader(title: 'Relationships', count: links.length),
        for (final link in links)
          ListTile(
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: RememberemTheme.gutter,
            ),
            horizontalTitleGap: RememberemTheme.thumbGap,
            minLeadingWidth: RememberemTheme.thumbSmall.width,
            leading: PortraitThumb(
              photo: photoOf(link.person),
              size: RememberemTheme.thumbSmall,
            ),
            title: Text(link.person.displayName),
            subtitle: Text(_describe(link)),
            trailing: const Icon(Icons.chevron_right_rounded),
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
