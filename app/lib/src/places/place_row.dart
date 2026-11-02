import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/memory_tile.dart';

/// One place in the list: name, how many people and when last, and when
/// selected, the names of the people met there.
class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.group,
    required this.expanded,
    required this.onTap,
    required this.onRename,
  });

  /// Height of a collapsed row; the list scrolls by multiples of it.
  static const collapsedExtent = 72.0;

  final PlaceGroup group;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onRename;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final person in people) Text(MemoryTile.nameOf(person)),
              ],
            ),
          ),
      ],
    );
  }
}
