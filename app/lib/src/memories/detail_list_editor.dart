import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';

/// The Details section: one dictatable box per detail, plus an empty box to
/// start the next one and an "Add detail" button for more.
class DetailListEditor extends StatefulWidget {
  const DetailListEditor({
    super.key,
    required this.details,
    required this.dictation,
    required this.onChanged,
  });

  final List<Detail> details;
  final Dictation dictation;

  /// Called with a row's id and text whenever the user changes that row.
  final void Function(String id, String text) onChanged;

  @override
  State<DetailListEditor> createState() => _DetailListEditorState();
}

class _DetailListEditorState extends State<DetailListEditor> {
  late final List<_Row> _rows = [
    for (final detail in widget.details) _Row(detail.id, detail.text),
    _Row.blank(),
  ];

  void _addRow() => setState(() => _rows.add(_Row.blank()));

  @override
  Widget build(BuildContext context) {
    // A Column, not a lazy list, so rows (and a live dictation) are never
    // disposed while scrolled out of view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, row) in _rows.indexed) ...[
          if (index > 0) const SizedBox(height: 16),
          DictatedTextField(
            key: ValueKey(row.id),
            label: index == 0 ? 'Detail' : 'Detail ${index + 1}',
            initialValue: row.initialText,
            dictation: widget.dictation,
            multiline: true,
            onChanged: (text) => widget.onChanged(row.id, text),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add detail'),
          ),
        ),
      ],
    );
  }
}

class _Row {
  _Row(this.id, this.initialText);

  _Row.blank()
    : id = DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      initialText = '';

  final String id;
  final String initialText;
}
