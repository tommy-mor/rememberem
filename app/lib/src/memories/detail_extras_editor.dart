import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

/// A detail's extra data, edited in place under its description: a
/// happening's date and place; a relationship's person (first) and type;
/// an anniversary's type and first date. Every change is passed on at
/// once as a copy of [detail] (so its score is kept).
class DetailExtrasEditor extends StatefulWidget {
  const DetailExtrasEditor({
    super.key,
    required this.detail,
    required this.ownerId,
    required this.people,
    required this.photoOf,
    required this.onChanged,
  });

  final Detail detail;

  /// The person the detail is about; never offered as their own relation.
  final String ownerId;

  /// Everyone active (relationship choices) and in the trash too (types
  /// still in use).
  final List<Memory> people;

  /// A person's photo, for the thumbnails beside names.
  final File Function(Memory person) photoOf;
  final ValueChanged<Detail> onChanged;

  @override
  State<DetailExtrasEditor> createState() => _DetailExtrasEditorState();
}

class _DetailExtrasEditorState extends State<DetailExtrasEditor> {
  late final _place = TextEditingController(text: widget.detail.place ?? '');
  final _placeFocus = FocusNode();
  late final List<String> _labels = DetailTypeCatalog.labels(
    widget.detail.kind,
    widget.people,
  );
  late final _custom = TextEditingController(
    text: _isListed(widget.detail.label) ? '' : widget.detail.label ?? '',
  );

  Detail get _detail => widget.detail;

  bool _isListed(String? label) {
    final key = DetailTypeCatalog.normalizeKey(label ?? '');
    return key.isEmpty ||
        _labels.any((l) => DetailTypeCatalog.normalizeKey(l) == key);
  }

  @override
  void didUpdateWidget(DetailExtrasEditor old) {
    super.didUpdateWidget(old);
    // A place filled in from where the phone is, while Fred is elsewhere.
    final place = _detail.place ?? '';
    if (!_placeFocus.hasFocus && _place.text != place) _place.text = place;
  }

  @override
  void dispose() {
    _place.dispose();
    _placeFocus.dispose();
    _custom.dispose();
    super.dispose();
  }

  List<Memory> get _others => [
    for (final m in widget.people)
      if (m.id != widget.ownerId && m.trashedAt == null) m,
  ];

  Future<void> _pickHappeningTime() async {
    final at = _detail.at.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: at,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(at),
    );
    if (time == null || !mounted) return;
    widget.onChanged(
      _detail.copyWith(
        at: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ),
    );
  }

  Future<void> _pickEventDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _detail.eventDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted) {
      widget.onChanged(_detail.copyWith(eventDate: date));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_detail.kind) {
          DetailKind.happening => _happening(context),
          DetailKind.relationship => [
            _who(context),
            const SizedBox(height: 8),
            ..._types(context, 'Create a custom relationship type'),
          ],
          DetailKind.anniversary => [
            ..._types(context, 'Create a custom anniversary type'),
            _eventDate(context),
          ],
          DetailKind.fact => const [],
        },
      ),
    );
  }

  List<Widget> _happening(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final at = _detail.at.toLocal();
    return [
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(
          '${l.formatMediumDate(at)}, '
          '${l.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
        ),
        subtitle: const Text('When it happened'),
        onTap: _pickHappeningTime,
      ),
      TextField(
        controller: _place,
        focusNode: _placeFocus,
        decoration: const InputDecoration(
          labelText: 'Place',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => widget.onChanged(_detail.copyWith(place: v)),
      ),
    ];
  }

  Widget _who(BuildContext context) {
    final others = _others;
    final target = _detail.targetId;
    return DropdownButtonFormField<String>(
      initialValue: others.any((m) => m.id == target) ? target : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Who',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final m in others)
          DropdownMenuItem(
            value: m.id,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    widget.photoOf(m),
                    width: 24,
                    height: 30,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox(width: 24, child: Icon(Icons.person)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: (id) => widget.onChanged(_detail.copyWith(targetId: () => id)),
    );
  }

  List<Widget> _types(BuildContext context, String customLabel) {
    final chosen = DetailTypeCatalog.normalizeKey(_detail.label ?? '');
    return [
      Wrap(
        spacing: 6,
        runSpacing: 0,
        children: [
          for (final label in _labels)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(label),
              selected:
                  _custom.text.trim().isEmpty &&
                  DetailTypeCatalog.normalizeKey(label) == chosen,
              onSelected: (_) {
                _custom.clear();
                widget.onChanged(_detail.copyWith(label: label));
              },
            ),
        ],
      ),
      const SizedBox(height: 4),
      TextField(
        controller: _custom,
        textCapitalization: TextCapitalization.none,
        decoration: InputDecoration(
          labelText: customLabel,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          // Emptying the box keeps the type chosen before it.
          if (v.trim().isNotEmpty) {
            widget.onChanged(_detail.copyWith(label: v.trim()));
          } else {
            setState(() {});
          }
        },
      ),
    ];
  }

  Widget _eventDate(BuildContext context) {
    final when = _detail.eventDate;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(
        when == null
            ? 'Choose the first date'
            : MaterialLocalizations.of(context).formatMediumDate(when),
      ),
      subtitle: const Text('When it first happened'),
      onTap: _pickEventDate,
    );
  }
}
