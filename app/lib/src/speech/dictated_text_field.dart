import 'package:flutter/material.dart';

import '../app/allow_in_settings.dart';
import '../app/rememberem_theme.dart';

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
    this.hint,
    this.dense = false,
    this.autofocus = false,
    this.showMic = true,
    this.trailing,
    this.alwaysFloatLabel = false,
    this.onListeningChanged,
  });

  final String label;
  final String initialValue;
  final Dictation dictation;
  final ValueChanged<String> onChanged;
  final bool multiline;

  /// Shown greyed out while the field is empty.
  final String? hint;

  /// Tighter padding, for rows in a list.
  final bool dense;
  final bool autofocus;

  /// Without the mic, [trailing] (if any) takes its place.
  final bool showMic;
  final Widget? trailing;

  /// Keeps the label on the border even while the field is empty.
  final bool alwaysFloatLabel;

  /// Told when listening starts and stops.
  final ValueChanged<bool>? onListeningChanged;

  /// Said when the phone has no offline speech for the language.
  static const noSpeechPack =
      "Your phone hasn't downloaded offline speech for this language. "
      "Download it in your phone's speech or language settings, or type.";

  @override
  State<DictatedTextField> createState() => _DictatedTextFieldState();
}

class _DictatedTextFieldState extends State<DictatedTextField>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _listening = false;

  /// Pulses the stop icon while listening; stopped otherwise, so tests and
  /// the screen settle.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0.4,
  );

  @override
  void dispose() {
    if (_listening) {
      _listening = false;
      widget.dictation.stop();
    }
    _pulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setListening(bool listening) {
    setState(() => _listening = listening);
    widget.onListeningChanged?.call(listening);
    if (listening) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await widget.dictation.stop();
      return;
    }
    _setListening(true);
    // Speech is added after anything already typed.
    final before = _controller.text.trim();
    final available = await widget.dictation.listen(
      onWords: (words) {
        // dispose() stops dictation without waiting; ignore a late result.
        if (!mounted) return;
        _controller.text = before.isEmpty ? words : '$before $words';
        widget.onChanged(_controller.text);
      },
      onDone: () {
        // Not listening any more means dispose() already stopped us.
        if (mounted && _listening) _setListening(false);
      },
      onNoSpeechPack: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(DictatedTextField.noSpeechPack),
            duration: Duration(seconds: 8),
          ),
        );
      },
    );
    if (!available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AllowInSettings.snackBar(
          "Dictation isn't available. If the microphone is off for "
          'Rememberem, allow it in Settings. You can always type.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      textCapitalization: widget.multiline
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      minLines: 1,
      maxLines: widget.multiline ? 5 : 1,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        isDense: widget.dense,
        contentPadding: widget.dense ? RememberemTheme.denseFieldPadding : null,
        // Keep the label up so the hint shows while the field is empty.
        floatingLabelBehavior: widget.hint != null || widget.alwaysFloatLabel
            ? FloatingLabelBehavior.always
            : null,
        border: const OutlineInputBorder(),
        suffixIcon: !widget.showMic && !_listening
            ? widget.trailing
            : IconButton(
                tooltip: _listening
                    ? 'Stop listening'
                    : 'Speak ${widget.label}',
                icon: _listening
                    ? FadeTransition(
                        opacity: _pulse,
                        child: ScaleTransition(
                          scale: _pulse.drive(Tween(begin: 0.85, end: 1.15)),
                          child: const Icon(Icons.stop_circle),
                        ),
                      )
                    : const Icon(Icons.mic),
                color: _listening ? Theme.of(context).colorScheme.error : null,
                onPressed: _toggleListening,
              ),
      ),
    );
  }
}
