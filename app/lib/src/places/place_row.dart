import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/person_chip.dart';

/// One place in the list: its name in a box, edited in place; below it its
/// radius in a box (tap to slide it) and, at the right, whether arriving
/// there gives a notice; then how many people and when last, after an
/// expander that shows the people met there, each with their photo
/// (tapping one opens them). Tapping the row selects the place.
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

  /// Least height of a collapsed row; the list scrolls by about this much
  /// a row (scaled with the text).
  static const collapsedExtent = 152.0;

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
  /// How far what sits under the name is set in: past the name box's
  /// left edge (the pin and its gap are 36).
  static const _indent = 52.0;

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
    return Material(
      color: widget.selected
          ? theme.colorScheme.primaryContainer.withAlpha(90)
          : Colors.transparent,
      child: InkWell(
        // Tapping the row, not its name, ends any name being typed.
        onTap: () {
          FocusScope.of(context).unfocus();
          widget.onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PlaceRow.collapsedExtent,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      group.marker == null ? Icons.help_outline : Icons.place,
                      color: widget.selected ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _nameField()),
                  ],
                ),
                if (radius != null || notify != null)
                  Padding(
                    padding: const EdgeInsets.only(left: _indent, top: 4),
                    child: Row(
                      // The Notify box keeps to the right.
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.slider case final slider?)
                          Flexible(child: slider)
                        else if (radius != null)
                          // Flexible, so large text wraps, not overflows.
                          Flexible(
                            child: OutlinedButton(
                              // Half the usual padding.
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: widget.onRadius,
                              child: Text(
                                '$radius radius',
                                semanticsLabel:
                                    '$radius radius, adjust for ${group.label}',
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const SizedBox(width: 8),
                        if (notify != null) _notifyBox(group, notify),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: _indent - 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: widget.expanded
                            ? 'Hide the people met at ${group.label}'
                            : 'Show the people met at ${group.label}',
                        icon: Icon(
                          widget.expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        onPressed: widget.onExpand,
                      ),
                      Expanded(
                        child: Text(
                          '$count · $date',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_indent, 0, 8, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final person in people)
                          PersonChip(
                            memory: person,
                            repository: widget.repository,
                            onTap: () => widget.onOpenPerson(person),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
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
          ExcludeSemantics(
            child: GestureDetector(
              onTap: onNotify == null ? null : () => onNotify(!notify),
              child: const Text('Notify'),
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

  /// The name in an outlined box, so it plainly can be edited.
  Widget _nameField() {
    final group = widget.group;
    return TextField(
      controller: _name,
      focusNode: _focus,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        isDense: true,
        // Half the usual padding.
        contentPadding: const EdgeInsets.fromLTRB(4, 7, 4, 4),
        border: const OutlineInputBorder(),
        // Only an unknown place shows a hint (it has no name yet).
        hintText: group.name == null ? group.label : null,
        suffixIcon: _changed
            ? IconButton(
                tooltip: 'Save the name',
                icon: const Icon(Icons.check),
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
