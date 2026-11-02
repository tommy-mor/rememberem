import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';

/// The Details section: one box per detail with its kind small in the
/// corner, its date, place, type or person before the description (tap
/// to change them), and a dictatable description. Below, a button to add
/// each kind. Details can be deleted, with Undo.
class DetailListEditor extends StatefulWidget {
  const DetailListEditor({
    super.key,
    required this.details,
    required this.dictation,
    required this.nameOf,
    required this.onChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final List<Detail> details;
  final Dictation dictation;

  /// The shown name of an active person, or null.
  final String? Function(String id) nameOf;

  /// Called with a detail's id and new description as it is typed.
  final void Function(String id, String text) onChanged;
  final void Function(DetailKind kind) onAdd;

  /// Fred wants to change [detail]'s date, place, type or person.
  final void Function(Detail detail) onEdit;
  final void Function(String id) onDelete;
  final void Function(Detail detail, int index) onRestore;

  /// The add buttons' labels, by kind.
  static String addLabel(DetailKind kind) => '+ ${kind.name}';

  @override
  State<DetailListEditor> createState() => _DetailListEditorState();
}

class _DetailListEditorState extends State<DetailListEditor> {
  void _delete(Detail detail) {
    final index = widget.details.indexWhere((d) => d.id == detail.id);
    widget.onDelete(detail.id);
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
          const SizedBox(height: 8),
          _row(context, detail),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final kind in DetailKind.values)
              OutlinedButton(
                onPressed: () => widget.onAdd(kind),
                child: Text(DetailListEditor.addLabel(kind)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Detail detail) {
    final theme = Theme.of(context);
    final prompt = DetailPrompt(detail, widget.nameOf);
    final prefix = prompt.prefix;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prompt.caption,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete ${prompt.caption}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(detail),
                ),
              ],
            ),
            if (prefix.isNotEmpty)
              InkWell(
                onTap: () => widget.onEdit(detail),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(prefix, style: theme.textTheme.titleSmall),
                      ),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DictatedTextField(
                key: ValueKey(detail.id),
                label: 'Description',
                initialValue: detail.text,
                dictation: widget.dictation,
                multiline: true,
                onChanged: (text) => widget.onChanged(detail.id, text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
