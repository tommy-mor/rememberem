import 'package:flutter/material.dart';

/// Asks before deleting a person forever, naming them.
class PurgeConfirmDialog extends StatelessWidget {
  const PurgeConfirmDialog({super.key, required this.name});

  final String name;

  /// True only if the user chose Delete.
  static Future<bool> show(BuildContext context, String name) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => PurgeConfirmDialog(name: name),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete $name forever?'),
      content: const Text(
        'This deletes their photo and notes from this phone. Notes about '
        'them on other people stay, but no longer link to them.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
