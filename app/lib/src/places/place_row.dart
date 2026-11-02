import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/person_chip.dart';

/// One place in the list: name, how many people and when last, and when
/// selected, the people met there, each with their photo; tapping one
/// opens them.
class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.group,
    required this.expanded,
    required this.onTap,
    required this.onRename,
    required this.onOpenPerson,
    required this.repository,
  });

  /// Height of a collapsed row; the list scrolls by multiples of it.
  static const collapsedExtent = 72.0;

  final PlaceGroup group;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final ValueChanged<Memory> onOpenPerson;
  final MemoryRepository repository;

  @override
  Widget build(BuildContext context) {
    final people = group.people;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(group.newest.toLocal());
    final count = people.length == 1 ? '1 person' : '${people.length} people';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: collapsedExtent,
          child: ListTile(
            selected: expanded,
            leading: Icon(
              group.marker == null ? Icons.help_outline : Icons.place,
            ),
            title: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('$count · $date', maxLines: 1),
            trailing: IconButton(
              tooltip: 'Rename ${group.label}',
              icon: const Icon(Icons.edit),
              onPressed: onRename,
            ),
            onTap: onTap,
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final person in people)
                  PersonChip(
                    memory: person,
                    repository: repository,
                    onTap: () => onOpenPerson(person),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
