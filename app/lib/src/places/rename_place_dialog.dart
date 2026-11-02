import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// Asks for a place's new name. Warns when the name is already another
/// place's (the two will merge) and says how many people it touches.
class RenamePlaceDialog extends StatefulWidget {
  const RenamePlaceDialog({
    super.key,
    required this.group,
    required this.otherNames,
    required this.peopleAffected,
  });

  final PlaceGroup group;
  final List<String> otherNames;
  final int peopleAffected;

  /// The trimmed new name, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required PlaceGroup group,
    required List<String> otherNames,
    required int peopleAffected,
  }) => showDialog<String>(
    context: context,
    builder: (_) => RenamePlaceDialog(
      group: group,
      otherNames: otherNames,
      peopleAffected: peopleAffected,
    ),
  );

  @override
  State<RenamePlaceDialog> createState() => _RenamePlaceDialogState();
}

class _RenamePlaceDialogState extends State<RenamePlaceDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  @override
  Widget build(BuildContext context) {
    final mergesWith = widget.otherNames.any(
      (n) => MeetingFinder.samePlace(n, _trimmed),
    );
    final count = widget.peopleAffected;
    return AlertDialog(
      title: Text(
        widget.group.name == null ? 'Name this place' : 'Rename place',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Place name',
              errorText: _trimmed.isEmpty ? 'Enter a name' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(count == 1 ? 'Changes 1 person.' : 'Changes $count people.'),
          if (mergesWith)
            Text(
              '"$_trimmed" already exists; the two places will become one.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _trimmed.isEmpty
              ? null
              : () => Navigator.of(context).pop(_trimmed),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
