import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';

/// The Details section: one dictatable box per detail, plus an empty box to
/// start the next one and an "Add detail" button for more. Each saved
/// detail shows when it was recorded (long-press to change) and can be
/// deleted, with Undo.
class DetailListEditor extends StatefulWidget {
  const DetailListEditor({
    super.key,
    required this.details,
    required this.dictation,
    required this.onChanged,
    required this.onTimeChanged,
    required this.onDelete,
    required this.onRestore,
  });

  /// The details as currently edited; rows without one here are unsaved.
  final List<Detail> details;
  final Dictation dictation;

  /// Called with a row's id and text whenever the user changes that row.
  final void Function(String id, String text) onChanged;
  final void Function(String id, DateTime at) onTimeChanged;
  final void Function(String id) onDelete;
  final void Function(Detail detail, int index) onRestore;

  @override
  State<DetailListEditor> createState() => _DetailListEditorState();
}

class _DetailListEditorState extends State<DetailListEditor> {
  late final List<_Row> _rows = [
    for (final detail in widget.details) _Row(detail.id, detail.text),
    _Row.blank(),
  ];

  void _addRow() => setState(() => _rows.add(_Row.blank()));

  Detail? _savedDetail(String id) {
    for (final detail in widget.details) {
      if (detail.id == id && detail.text.trim().isNotEmpty) return detail;
    }
    return null;
  }

  void _delete(int rowIndex) {
    final row = _rows[rowIndex];
    final detail = _savedDetail(row.id);
    final detailIndex = widget.details.indexWhere((d) => d.id == row.id);
    widget.onDelete(row.id);
    setState(() {
      _rows.removeAt(rowIndex);
      if (_rows.isEmpty) _rows.add(_Row.blank());
    });
    if (detail == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Detail deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // The card may have closed; its last save already ran.
              if (!mounted) return;
              widget.onRestore(detail, detailIndex);
              setState(
                () => _rows.insert(
                  min(rowIndex, _rows.length),
                  _Row(detail.id, detail.text),
                ),
              );
            },
          ),
        ),
      );
  }

  Future<void> _editTime(Detail detail) async {
    final local = detail.at.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Confirming the same minute must not drop the seconds already stored.
    if (picked ==
        DateTime(
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
        )) {
      return;
    }
    widget.onTimeChanged(detail.id, picked);
  }

  @override
  Widget build(BuildContext context) {
    // A Column, not a lazy list, so rows (and a live dictation) are never
    // disposed while scrolled out of view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, row) in _rows.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _header(context, index, row),
          DictatedTextField(
            key: ValueKey(row.id),
            label: _label(index),
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

  String _label(int index) => index == 0 ? 'Detail' : 'Detail ${index + 1}';

  Widget _header(BuildContext context, int index, _Row row) {
    final detail = _savedDetail(row.id);
    final canDelete = detail != null || _rows.length > 1;
    if (detail == null && !canDelete) return const SizedBox(height: 8);
    return Row(
      children: [
        Expanded(
          child: detail == null
              ? const SizedBox(height: 48)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _editTime(detail),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatTime(context, detail.at),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
        ),
        if (canDelete)
          IconButton(
            tooltip: 'Delete ${_label(index)}',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(index),
          ),
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatFullDate(local)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
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
