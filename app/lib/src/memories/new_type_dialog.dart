import 'package:flutter/material.dart';

/// Asks for the name of a new relationship, anniversary or tag type.
/// Returns the trimmed name, or null if Fred cancelled or left it blank.
class NewTypeDialog extends StatefulWidget {
  const NewTypeDialog({super.key, required this.title});

  /// "New tag", "New relationship type".
  final String title;

  static Future<String?> show(BuildContext context, String title) =>
      showDialog<String>(
        context: context,
        builder: (_) => NewTypeDialog(title: title),
      );

  @override
  State<NewTypeDialog> createState() => _NewTypeDialogState();
}

class _NewTypeDialogState extends State<NewTypeDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _add(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _name.text.trim().isEmpty ? null : _add,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
