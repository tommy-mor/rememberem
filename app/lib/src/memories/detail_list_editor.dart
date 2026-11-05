import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../app/section_header.dart';
import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';
import 'detail_extras_editor.dart';
import 'detail_help_dialog.dart';

/// The details, one section per kind under a tinted header with its count
/// and a "+" to add one. Each detail is a row: closed, one line
/// ([DetailSummary]) and any problem in red; open (its row tapped), a raised
/// card with the kind's extras, the description with its mic, and help,
/// close and delete along the bottom. Tapping outside an open card, or
/// focus leaving it, closes it. A new detail opens, with nothing focused. Details can be
/// deleted, with Undo.
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
    this.generation = 0,
    this.onListeningChanged,
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

  /// Bumped when the details were replaced from outside (Undo), so the
  /// description fields read their text again.
  final int generation;

  /// Told when any row's dictation starts or stops.
  final ValueChanged<bool>? onListeningChanged;

  /// The "+" buttons' tooltips, by kind.
  static String addLabel(DetailKind kind) =>
      'Add ${kind == DetailKind.anniversary ? 'an' : 'a'} '
      '${kind.label.toLowerCase()}';

  /// Shown on a closed card with nothing entered yet.
  static const nothingYet = 'Nothing entered yet';

  /// The description field's placeholder.
  static const describeHint = 'What to remember';

  /// Red on a closed tag with no tag chosen.
  static const noTag = 'No tag chosen';

  /// Red on a closed anniversary with no date.
  static const noDate = 'No date';

  /// What is missing from [detail], said in red on its closed card.
  static String? problemOf(Detail detail) => switch (detail.kind) {
    DetailKind.tag when (detail.label?.trim() ?? '').isEmpty => noTag,
    DetailKind.anniversary when detail.eventDate == null => noDate,
    _ => null,
  };

  @override
  State<DetailListEditor> createState() => _DetailListEditorState();
}

class _DetailListEditorState extends State<DetailListEditor> {
  /// Rows showing their extra data.
  final Set<String> _open = {};

  /// A row coming back through Undo, which is not new.
  String? _restoring;

  /// Rows whose dictation is listening; they stay open until it ends.
  final Set<String> _listening = {};

  /// Each row's focus, to tell whether the keyboard is in it.
  final Map<String, FocusNode> _rowFocus = {};

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusMoved);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusMoved);
    for (final node in _rowFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// A text field elsewhere took the keyboard: open rows it is not in
  /// close, even one opened with nothing in it focused. (Other fields are
  /// in the rows' tap group, so tapping them is not "outside".)
  void _focusMoved() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.findAncestorWidgetOfExactType<EditableText>() == null) {
      return;
    }
    for (final id in [..._open]) {
      if (_rowFocus[id]?.hasFocus != true) _collapse(id);
    }
  }

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

  void _setListening(String id, bool listening) {
    listening ? _listening.add(id) : _listening.remove(id);
    widget.onListeningChanged?.call(_listening.isNotEmpty);
  }

  @override
  void didUpdateWidget(DetailListEditor old) {
    super.didUpdateWidget(old);
    final before = {for (final d in old.details) d.id};
    final now = {for (final d in widget.details) d.id};
    for (final d in widget.details) {
      if (before.contains(d.id) || d.id == _restoring) continue;
      // Added just now: it opens, but takes no focus, so no keyboard.
      // Brought back by Undo (a new generation), it stays closed.
      if (widget.generation == old.generation) _open.add(d.id);
    }
    _open.retainAll(now);
    _restoring = null;
  }

  void _delete(Detail detail) {
    final index = widget.details.indexWhere((d) => d.id == detail.id);
    widget.onDelete(detail.id);
    _open.remove(detail.id);
    _setListening(detail.id, false);
    // An empty row has nothing worth bringing back.
    if (detail.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Detail deleted'),
          // Undo snackbars would otherwise stay until dismissed.
          persist: false,
          duration: const Duration(seconds: 10),
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
        for (final kind in DetailKind.values) ...[
          _heading(context, kind),
          for (final detail in widget.details)
            if (detail.kind == kind) _row(context, detail),
        ],
      ],
    );
  }

  Widget _heading(BuildContext context, DetailKind kind) => SectionHeader(
    title: kind.plural,
    count: widget.details.where((d) => d.kind == kind).length,
    trailing: IconButton(
      tooltip: DetailListEditor.addLabel(kind),
      icon: const Icon(Icons.add_rounded),
      onPressed: () => widget.onAdd(kind),
    ),
  );

  Widget _row(BuildContext context, Detail detail) {
    final id = detail.id;
    final name = DetailSummary.spokenName(detail, widget.nameOf);
    final open = _open.contains(id);
    // In the text fields' group, so the paste toolbar and selection
    // handles (overlays) count as inside; tapping another field still
    // closes the row, through focus leaving it.
    return TapRegion(
      key: ValueKey('detail-$id'),
      groupId: EditableText,
      onTapOutside: (_) => _collapse(id),
      child: Focus(
        focusNode: _rowFocus.putIfAbsent(
          id,
          () => FocusNode(canRequestFocus: false, skipTraversal: true),
        ),
        onFocusChange: (focused) {
          if (!focused) _collapse(id);
        },
        child: open
            ? _opened(context, detail, name)
            : _closed(context, detail, name),
      ),
    );
  }

  /// One line, never wrapped, and any problem in red below it; a rule
  /// under it, from the text.
  Widget _closed(BuildContext context, Detail detail, String name) {
    final theme = Theme.of(context);
    final line = DetailSummary.lineFor(detail, widget.nameOf);
    final problem = DetailListEditor.problemOf(detail);
    final target = detail.kind == DetailKind.relationship
        ? widget.people.where((m) => m.id == detail.targetId).firstOrNull
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _expand(detail.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: RememberemTheme.tapTarget,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                RememberemTheme.gutter,
                8,
                4,
                8,
              ),
              child: Row(
                children: [
                  if (target != null) ...[
                    PortraitThumb(
                      photo: widget.photoOf(target),
                      size: RememberemTheme.thumbSmall,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.isEmpty ? DetailListEditor.nothingYet : line,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: line.isEmpty
                              ? theme.inputDecorationTheme.hintStyle
                              : null,
                        ),
                        if (problem != null)
                          Text(
                            problem,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, semanticLabel: 'Open $name'),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: RememberemTheme.gutter,
          color: RememberemTheme.rule(theme),
        ),
      ],
    );
  }

  /// A raised card, inset from the page: the kind's extras, the
  /// description last, then help, close and delete.
  Widget _opened(BuildContext context, Detail detail, String name) {
    final id = detail.id;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Material(
        color: RememberemTheme.raised(theme),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detail.kind != DetailKind.fact)
                DetailExtrasEditor(
                  key: ValueKey('extras-$id'),
                  detail: detail,
                  ownerId: widget.ownerId,
                  people: widget.people,
                  photoOf: widget.photoOf,
                  choosePlace: widget.choosePlace,
                  onChanged: widget.onReplace,
                ),
              DictatedTextField(
                key: ValueKey('$id-${widget.generation}'),
                ledger: true,
                label: 'Description',
                hint: DetailListEditor.describeHint,
                initialValue: detail.text,
                dictation: widget.dictation,
                multiline: true,
                onListeningChanged: (listening) => _setListening(id, listening),
                onChanged: (text) => widget.onChanged(id, text),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'About ${detail.kind.label.toLowerCase()} details',
                    icon: const Icon(Icons.help_outline_rounded),
                    onPressed: () =>
                        DetailHelpDialog.show(context, detail.kind),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close $name',
                    icon: const Icon(Icons.expand_less_rounded),
                    onPressed: () => _collapse(id),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete $name',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(detail),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
