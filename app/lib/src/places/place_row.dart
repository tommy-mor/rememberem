import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../memories/person_chip.dart';

/// One place in the list: its name, edited in place, its radius, how many
/// people and when last, and when selected, the people met there, each
/// with their photo; tapping one opens them.
class PlaceRow extends StatefulWidget {
  const PlaceRow({
    super.key,
    required this.group,
    required this.expanded,
    required this.onTap,
    required this.onRename,
    required this.onOpenPerson,
    required this.repository,
    this.radius,
    this.onRadius,
    this.slider,
  });

  /// Least height of a collapsed row; the list scrolls by multiples of it
  /// (scaled with the text).
  static const collapsedExtent = 72.0;

  final PlaceGroup group;
  final bool expanded;
  final VoidCallback onTap;

  /// Renames the place; true if it was renamed (Fred may cancel).
  final Future<bool> Function(String newName) onRename;
  final ValueChanged<Memory> onOpenPerson;
  final MemoryRepository repository;

  /// The radius as text ("555 ft"), for named places only.
  final String? radius;
  final VoidCallback? onRadius;

  /// While the radius is being slid, the slider, in place of [radius].
  final Widget? slider;

  @override
  State<PlaceRow> createState() => _PlaceRowState();
}

class _PlaceRowState extends State<PlaceRow> {
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
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(group.newest.toLocal());
    final count = people.length == 1 ? '1 person' : '${people.length} people';
    final radius = widget.radius;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PlaceRow.collapsedExtent,
          ),
          child: ListTile(
            selected: widget.expanded,
            leading: Icon(
              group.marker == null ? Icons.help_outline : Icons.place,
            ),
            title: TextField(
              controller: _name,
              focusNode: _focus,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
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
            ),
            subtitle: Text('$count · $date', maxLines: 1),
            trailing:
                widget.slider ??
                (radius == null
                    ? null
                    : TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: widget.onRadius,
                        child: Text(
                          radius,
                          semanticsLabel:
                              'Radius of ${group.label}: $radius. Adjust',
                        ),
                      )),
            // Tapping the row, not its name, ends any name being typed.
            onTap: () {
              FocusScope.of(context).unfocus();
              widget.onTap();
            },
          ),
        ),
        if (widget.expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
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
    );
  }
}
