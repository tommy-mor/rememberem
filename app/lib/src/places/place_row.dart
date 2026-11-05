import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/pill_button.dart';
import '../app/rememberem_theme.dart';
import '../app/selected_row.dart';
import '../memories/memory_tile.dart';

/// One place in the list: its name as a ledger field, edited in place; below
/// it its radius as a pill (tap to slide it) and, at the right, whether
/// arriving there gives a notice; then how many people and when last, after
/// an expander that shows the people met there, a line each with their
/// photo (tapping one opens them). Tapping the row selects the place.
class PlaceRow extends StatefulWidget {
  const PlaceRow({
    super.key,
    required this.group,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.onExpand,
    required this.onRename,
    required this.onOpenPerson,
    required this.repository,
    this.radius,
    this.onRadius,
    this.slider,
    this.notify,
    this.onNotify,
  });

  /// Measured height of a collapsed row at text scale 1.0 (a test keeps it
  /// honest), and the part of it that is text and so grows with the text
  /// scale; the rest (icons, buttons, padding) does not.
  static const collapsedExtent = 162.0;
  static const _collapsedText = 37.0;

  /// The same for one expanded person (a `MemoryTile` and its rule).
  static const personExtent = 59.0;
  static const _personText = 35.0;

  /// A collapsed row's height under [scaler], for the list to scroll by.
  static double collapsedHeight(TextScaler scaler) =>
      collapsedExtent + scaler.scale(_collapsedText) - _collapsedText;

  /// One expanded person's height under [scaler].
  static double personHeight(TextScaler scaler) =>
      personExtent + scaler.scale(_personText) - _personText;

  final PlaceGroup group;

  /// The place chosen on the map.
  final bool selected;

  /// The people met there are showing.
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onExpand;

  /// Renames the place; true if it was renamed (Fred may cancel).
  final Future<bool> Function(String newName) onRename;
  final ValueChanged<Memory> onOpenPerson;
  final MemoryRepository repository;

  /// The radius as text ("555 ft"), for named places only.
  final String? radius;
  final VoidCallback? onRadius;

  /// While the radius is being slid, the slider, in place of [radius].
  final Widget? slider;

  /// Whether arriving here gives a place notice; null for an unknown
  /// place, which has none.
  final bool? notify;
  final ValueChanged<bool>? onNotify;

  @override
  State<PlaceRow> createState() => _PlaceRowState();
}

class _PlaceRowState extends State<PlaceRow> {
  /// How far what sits under the name is set in: to the name's own left
  /// edge, past the pin's slot and its gap (the text line of every list).
  static const _indent = RememberemTheme.rowTextInset - RememberemTheme.gutter;

  /// Kept clear at the end for the selected row's check.
  static const _endReserve = RememberemTheme.gutter + 22 + 4;

  late final _name = TextEditingController(text: widget.group.name ?? '');
  final _focus = FocusNode();

  String get _saved => widget.group.name ?? '';

  bool get _changed {
    final typed = _name.text.trim();
    return typed.isNotEmpty && typed != _saved;
  }

  @override
  void initState() {
    super.initState();
    // Leaving the field without Done puts the old name back, so a stray
    // tap never renames anything.
    _focus.addListener(() {
      if (!_focus.hasFocus && _name.text != _saved) {
        setState(() => _name.text = _saved);
      }
    });
  }

  @override
  void didUpdateWidget(PlaceRow old) {
    super.didUpdateWidget(old);
    if (old.group.name != widget.group.name && !_focus.hasFocus) {
      _name.text = _saved;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    if (_changed) {
      final renamed = await widget.onRename(_name.text.trim());
      if (!mounted) return;
      if (!renamed) _name.text = _saved;
    } else {
      _name.text = _saved;
    }
    _focus.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final people = group.people;
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(group.newest.toLocal());
    final count = people.length == 1 ? '1 person' : '${people.length} people';
    final radius = widget.radius;
    final notify = widget.notify;
    return SelectedRow(
      selected: widget.selected,
      // A name box, a radius, a Notify box and an expander: each its own
      // stop for a screen reader.
      mergeSemantics: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Tapping the row, not its name, ends any name being typed.
          onTap: () {
            FocusScope.of(context).unfocus();
            widget.onTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  RememberemTheme.gutter,
                  8,
                  _endReserve,
                  4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: RememberemTheme.thumbRow.width,
                          child: Icon(
                            group.marker == null
                                ? Icons.help_outline_rounded
                                : Icons.place_rounded,
                            color: widget.selected
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                        const SizedBox(width: RememberemTheme.thumbGap),
                        Expanded(child: _nameField(theme)),
                      ],
                    ),
                    if (radius != null || notify != null)
                      Padding(
                        padding: const EdgeInsets.only(left: _indent),
                        child: Wrap(
                          // The Notify box keeps to the right; a narrow
                          // screen or large text wraps it below.
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (widget.slider case final slider?)
                              slider
                            else if (radius != null)
                              PillButton(
                                label: '$radius radius',
                                tooltip:
                                    '$radius radius, adjust for ${group.label}',
                                onPressed: widget.onRadius,
                              ),
                            if (notify != null) _notifyBox(group, notify),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: _indent - 12),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: widget.expanded
                                ? 'Hide the people met at ${group.label}'
                                : 'Show the people met at ${group.label}',
                            icon: Icon(
                              widget.expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                            ),
                            onPressed: widget.onExpand,
                          ),
                          Expanded(
                            child: Text(
                              '$count · $date',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.expanded)
                // One person a line, their photos starting where the
                // place's name does.
                Padding(
                  padding: const EdgeInsets.only(left: _indent),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final person in people)
                        MemoryTile(
                          memory: person,
                          photo: widget.repository.photoFile(person),
                          onTap: () => widget.onOpenPerson(person),
                        ),
                    ],
                  ),
                ),
              Divider(
                height: 1,
                thickness: 1,
                indent: RememberemTheme.rowTextInset,
                color: RememberemTheme.rule(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Notify" and its box, at the right of the radius line.
  Widget _notifyBox(PlaceGroup group, bool notify) {
    final onNotify = widget.onNotify;
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible, so very large text wraps, not overflows.
          Flexible(
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onNotify == null ? null : () => onNotify(!notify),
                child: const Text('Notify'),
              ),
            ),
          ),
          Checkbox(
            value: notify,
            semanticLabel: 'Notify on arrival at ${group.label}',
            onChanged: onNotify == null ? null : (v) => onNotify(v ?? false),
          ),
        ],
      ),
    );
  }

  /// The name as a ledger field labelled PLACE, so it plainly can be
  /// edited.
  Widget _nameField(ThemeData theme) {
    final group = widget.group;
    return TextField(
      controller: _name,
      focusNode: _focus,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      decoration: RememberemTheme.ledgerDecoration(
        theme,
        label: 'Place',
        // Only an unknown place shows a hint (it has no name yet).
        hint: group.name == null ? group.label : null,
        suffix: _changed
            ? IconButton(
                tooltip: 'Save the name',
                icon: const Icon(Icons.check_rounded),
                onPressed: _commit,
              )
            : null,
      ),
      onTap: widget.onTap,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _commit(),
    );
  }
}
