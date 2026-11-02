import 'package:flutter/material.dart';

/// Asks what to call a spot on the map; pops with the trimmed name, or
/// nothing if Fred cancels.
class PlaceNameDialog extends StatefulWidget {
  const PlaceNameDialog({super.key, required this.initial});

  /// The known place nearby, if any, to accept or change.
  final String initial;

  @override
  State<PlaceNameDialog> createState() => _PlaceNameDialogState();
}

class _PlaceNameDialogState extends State<PlaceNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this place'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Place',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _done, child: const Text('OK')),
      ],
    );
  }
}
