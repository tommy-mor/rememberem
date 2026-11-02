import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';
import 'detail_extras_editor.dart';

/// The Details section: one line per detail, its kind and data as the
/// label on the field's border ("Happening · 3 Mar 2026 · Park") and its
/// description as the text, with an expander. Opening a row (the expander,
/// or tapping into it) draws a box round it holding the mic, the kind's
/// extras and a delete button; tapping outside the box, or focus leaving
/// it, closes it again. A new row opens. Below, a button to add each kind.
/// Details can be deleted, with Undo.
class DetailListEditor extends StatefulWidget {
  const DetailListEditor({
    super.key,
    required this.details,
    required this.dictation,
    required this.ownerId,
    required this.people,
    required this.photoOf,
    required this.choosePlace,
    required this.nameOf,
    required this.onChanged,
    required this.onReplace,
    required this.onAdd,
    required this.onDelete,
    required this.onRestore,
  });

  final List<Detail> details;
  final Dictation dictation;
  final String ownerId;

  /// Everyone active and in the trash, for relationship choices and types.
  final List<Memory> people;
  final File Function(Memory person) photoOf;

  /// Picks a happening's place on a map; see [DetailExtrasEditor].
  final Future<String?> Function(String current) choosePlace;

  /// The shown name of an active person, or null.
  final String? Function(String id) nameOf;

  /// Called with a detail's id and new description as it is typed.
  final void Function(String id, String text) onChanged;

  /// A detail's date, place, type or person changed.
  final ValueChanged<Detail> onReplace;
  final void Function(DetailKind kind) onAdd;
  final void Function(String id) onDelete;
  final void Function(Detail detail, int index) onRestore;

  /// The add buttons' labels, by kind.
  static String addLabel(DetailKind kind) => '+ ${kind.name}';

  /// A detail's kind and data on one line: "Relationship · Brother · Ann".
  static String rowLabel(Detail detail, String? Function(String id) nameOf) {
    final d = detail;
    final label = _capitalised(d.label?.trim() ?? '');
    final target = d.targetId;
    final parts = switch (d.kind) {
      DetailKind.fact => const <String>[],
      DetailKind.happening => [
        DetailPrompt.date(d.at.toLocal()),
        d.place?.trim() ?? '',
      ],
      DetailKind.relationship => [
        label,
        if (target != null) nameOf(target) ?? DetailPrompt.someoneRemoved,
      ],
      DetailKind.anniversary => [
        label,
        if (d.eventDate case final day?) DetailPrompt.date(day),
      ],
    };
    return [d.kind.label, ...parts.where((p) => p.isNotEmpty)].join(' · ');
  }

  static String _capitalised(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  State<DetailListEditor> createState() => _DetailListEditorState();
}

class _DetailListEditorState extends State<DetailListEditor> {
  /// Rows showing their extra data.
  final Set<String> _open = {};

  /// The row just added, whose description takes the keyboard.
  String? _added;

  /// A row coming back through Undo, which is not new.
  String? _restoring;

  /// Rows whose dictation is listening; they stay open until it ends.
  final Set<String> _listening = {};

  void _expand(String id) {
    if (!_open.contains(id)) setState(() => _open.add(id));
  }

  /// Closes row [id], unless it is listening or something (a picker, a
  /// menu, the map) is open over the page: those take focus and taps
  /// without leaving the row.
  void _collapse(String id) {
    if (!_open.contains(id) || _listening.contains(id)) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    setState(() => _open.remove(id));
  }

  @override
  void didUpdateWidget(DetailListEditor old) {
    super.didUpdateWidget(old);
    final before = {for (final d in old.details) d.id};
    for (final d in widget.details) {
      if (before.contains(d.id) || d.id == _restoring) continue;
      // Added just now (its place may already be filled in).
      _open.add(d.id);
      // A relationship starts with "Who", so the keyboard waits.
      _added = d.kind == DetailKind.relationship ? null : d.id;
    }
    _restoring = null;
  }

  void _delete(Detail detail) {
    final index = widget.details.indexWhere((d) => d.id == detail.id);
    widget.onDelete(detail.id);
    _open.remove(detail.id);
    _listening.remove(detail.id);
    // An empty row has nothing worth bringing back.
    if (detail.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Detail deleted'),
          // Undo snackbars would otherwise stay until dismissed.
          persist: false,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // The card may have closed; its last save already ran.
              if (!mounted) return;
              _restoring = detail.id;
              widget.onRestore(detail, index);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // A Column, not a lazy list, so a live dictation is never disposed
    // while scrolled out of view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Details', style: Theme.of(context).textTheme.titleSmall),
        for (final detail in widget.details) ...[
          const SizedBox(height: 6),
          _row(context, detail),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final kind in DetailKind.values)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onAdd(kind),
                child: Text(DetailListEditor.addLabel(kind)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Detail detail) {
    final id = detail.id;
    final label = DetailListEditor.rowLabel(detail, widget.nameOf);
    final open = _open.contains(id);
    final scheme = Theme.of(context).colorScheme;
    // The same widgets open or closed, so the description field (and any
    // dictation in it) is never rebuilt from scratch.
    // In the text fields' group, so the paste toolbar and selection
    // handles (overlays) count as inside; tapping another field still
    // closes the row, through focus leaving it.
    return TapRegion(
      key: ValueKey('detail-$id'),
      groupId: EditableText,
      onTapOutside: (_) => _collapse(id),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => focused ? _expand(id) : _collapse(id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: open ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.all(open ? 6 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DictatedTextField(
                  key: ValueKey(id),
                  label: label,
                  initialValue: detail.text,
                  dictation: widget.dictation,
                  multiline: true,
                  dense: true,
                  alwaysFloatLabel: true,
                  autofocus: _added == id,
                  showMic: open,
                  trailing: IconButton(
                    tooltip: 'Open $label',
                    icon: const Icon(Icons.expand_more),
                    onPressed: () => _expand(id),
                  ),
                  onListeningChanged: (listening) =>
                      listening ? _listening.add(id) : _listening.remove(id),
                  onChanged: (text) => widget.onChanged(id, text),
                ),
                if (open) ...[
                  if (detail.kind != DetailKind.fact)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: DetailExtrasEditor(
                        key: ValueKey('extras-$id'),
                        detail: detail,
                        ownerId: widget.ownerId,
                        people: widget.people,
                        photoOf: widget.photoOf,
                        choosePlace: widget.choosePlace,
                        onChanged: widget.onReplace,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete $label',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(detail),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
