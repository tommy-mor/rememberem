import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/rememberem_theme.dart';

/// A detail's extra data, edited in place under its description: a
/// happening's date and place (from a map); a relationship's person
/// (first) and type;
/// an anniversary's type and first date; a tag's type, place and date.
/// Every change is passed on at
/// once as a copy of [detail] (so its score is kept).
class DetailExtrasEditor extends StatefulWidget {
  const DetailExtrasEditor({
    super.key,
    required this.detail,
    required this.ownerId,
    required this.people,
    required this.photoOf,
    required this.choosePlace,
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

  /// Opens the map at [current] (a place name); the chosen place's name,
  /// or null if Fred went back.
  final Future<String?> Function(String current) choosePlace;
  final ValueChanged<Detail> onChanged;

  /// Shown on a tag while Fred has made none.
  static const noTagsYet =
      'Tags are a way to group people any way you like: relatives, '
      'celebrities, memberships and so on. Make your own below.';

  static const keepTagsKind =
      'Keep tags kind: words the person would be happy to read.';

  @override
  State<DetailExtrasEditor> createState() => _DetailExtrasEditorState();
}

class _DetailExtrasEditorState extends State<DetailExtrasEditor> {
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
  void dispose() {
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

  Future<void> _pickPlace() async {
    final place = await widget.choosePlace(_detail.place?.trim() ?? '');
    if (place != null && mounted) {
      widget.onChanged(_detail.copyWith(place: () => place));
    }
  }

  Future<void> _pickEventDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _detail.eventDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted) {
      widget.onChanged(_detail.copyWith(eventDate: () => date));
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
          DetailKind.tag => [
            if (_labels.isEmpty && (_detail.label?.trim() ?? '').isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(DetailExtrasEditor.noTagsYet),
              ),
            ..._types(context, 'Create a tag'),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DetailExtrasEditor.keepTagsKind,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _placeTile('Where (optional)', clearable: true),
            _tagDate(context),
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
        visualDensity: VisualDensity.compact,
        minVerticalPadding: 0,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(
          '${l.formatMediumDate(at)}, '
          '${l.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
        ),
        subtitle: const Text('When it happened'),
        onTap: _pickHappeningTime,
      ),
      _placeTile('Where it happened'),
    ];
  }

  Widget _placeTile(String subtitle, {bool clearable = false}) => ListTile(
    dense: true,
    visualDensity: VisualDensity.compact,
    minVerticalPadding: 0,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.place_outlined),
    title: Text(
      (_detail.place?.trim() ?? '').isEmpty
          ? 'Choose place'
          : _detail.place!.trim(),
    ),
    subtitle: Text(subtitle),
    trailing: clearable && (_detail.place?.trim() ?? '').isNotEmpty
        ? IconButton(
            tooltip: 'Clear the place',
            icon: const Icon(Icons.clear),
            onPressed: () =>
                widget.onChanged(_detail.copyWith(place: () => null)),
          )
        : null,
    onTap: _pickPlace,
  );

  Widget _tagDate(BuildContext context) {
    final when = _detail.eventDate;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 0,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(
        when == null
            ? 'Choose a date'
            : MaterialLocalizations.of(context).formatMediumDate(when),
      ),
      subtitle: const Text('When (optional)'),
      trailing: when == null
          ? null
          : IconButton(
              tooltip: 'Clear the date',
              icon: const Icon(Icons.clear),
              onPressed: () =>
                  widget.onChanged(_detail.copyWith(eventDate: () => null)),
            ),
      onTap: _pickEventDate,
    );
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
        contentPadding: RememberemTheme.denseFieldPadding,
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
                    cacheWidth: 80,
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
          contentPadding: RememberemTheme.denseFieldPadding,
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
      visualDensity: VisualDensity.compact,
      minVerticalPadding: 0,
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
