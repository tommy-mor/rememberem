import 'package:flutter/material.dart';

import 'dictation.dart';

/// A text field with a microphone button that fills it by speech.
class DictatedTextField extends StatefulWidget {
  const DictatedTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.dictation,
    required this.onChanged,
    this.multiline = false,
  });

  final String label;
  final String initialValue;
  final Dictation dictation;
  final ValueChanged<String> onChanged;
  final bool multiline;

  @override
  State<DictatedTextField> createState() => _DictatedTextFieldState();
}

class _DictatedTextFieldState extends State<DictatedTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) {
      _listening = false;
      widget.dictation.stop();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await widget.dictation.stop();
      return;
    }
    setState(() => _listening = true);
    // Speech is added after anything already typed.
    final before = _controller.text.trim();
    final available = await widget.dictation.listen(
      onWords: (words) {
        _controller.text = before.isEmpty ? words : '$before $words';
        widget.onChanged(_controller.text);
      },
      onDone: () {
        // Not listening any more means dispose() already stopped us.
        if (mounted && _listening) setState(() => _listening = false);
      },
    );
    if (!available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Speech recognition is not available. '
            'Check microphone permission in Settings.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textCapitalization: widget.multiline
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      minLines: 1,
      maxLines: widget.multiline ? 5 : 1,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _listening ? 'Stop listening' : 'Speak ${widget.label}',
          icon: Icon(_listening ? Icons.stop_circle : Icons.mic),
          color: _listening ? Theme.of(context).colorScheme.error : null,
          onPressed: _toggleListening,
        ),
      ),
    );
  }
}
