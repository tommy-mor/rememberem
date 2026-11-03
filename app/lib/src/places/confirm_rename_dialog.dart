import 'package:flutter/material.dart';

/// Asks before a known place is renamed: how many people it changes, and
/// whether it merges with another place of that name.
class ConfirmRenameDialog extends StatelessWidget {
  const ConfirmRenameDialog({
    super.key,
    required this.from,
    required this.to,
    required this.peopleAffected,
    required this.merges,
  });

  final String from;
  final String to;
  final int peopleAffected;
  final bool merges;

  /// True if Fred confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String from,
    required String to,
    required int peopleAffected,
    required bool merges,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => ConfirmRenameDialog(
          from: from,
          to: to,
          peopleAffected: peopleAffected,
          merges: merges,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final count = peopleAffected;
    return AlertDialog(
      title: const Text('Rename place?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rename "$from" to "$to"?'),
          const SizedBox(height: 8),
          Text(count == 1 ? 'Changes 1 person.' : 'Changes $count people.'),
          if (merges)
            Text(
              '"$to" already exists; the two places will become one.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
