import 'package:flutter/material.dart';

/// Asks before throwing away a photo whose people are not saved yet.
class DiscardPhotoDialog extends StatelessWidget {
  const DiscardPhotoDialog({super.key});

  /// True if Fred chose to discard.
  static Future<bool> show(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => const DiscardPhotoDialog(),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Discard this photo?'),
      content: const Text('No one in it has been saved yet.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep choosing'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}
