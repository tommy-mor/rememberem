import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/ledger_picker_field.dart';
import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import 'new_type_dialog.dart';
import 'pulsing_button.dart';

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
      'Tags group people any way you like: relatives, celebrities, '
      'memberships. Tap + to make one.';

  static const keepTagsKind =
      'Keep tag names kind: ones the person would be happy to read.';

  /// Shown while a tag has no type.
  static const needsType =
      "Choose a tag above or create one. Without it, this entry groups no "
      'one, and is not saved unless it has words.';

  @override
  State<DetailExtrasEditor> createState() => _DetailExtrasEditorState();
}

class _DetailExtrasEditorState extends State<DetailExtrasEditor> {
  /// The types to choose from, with this detail's own (and any made here)
  /// among them.
  late final List<String> _labels = _withOwn(
    DetailTypeCatalog.labels(widget.detail.kind, widget.people),
    widget.detail.label,
  );

  /// [labels], plus [own] if it is not blank and not already listed.
  static List<String> _withOwn(List<String> labels, String? own) {
    final key = DetailTypeCatalog.normalizeKey(own ?? '');
    final listed = labels.any((l) => DetailTypeCatalog.normalizeKey(l) == key);
    return [...labels, if (key.isNotEmpty && !listed) own!.trim()];
  }

  Detail get _detail => widget.detail;

  /// Asks for a new type's name and chooses it; a name already listed
  /// chooses that one.
  Future<void> _newType(String title) async {
    final name = await NewTypeDialog.show(context, title);
    if (name == null || !mounted) return;
    final key = DetailTypeCatalog.normalizeKey(name);
    final listed = _labels
        .where((l) => DetailTypeCatalog.normalizeKey(l) == key)
        .firstOrNull;
    if (listed == null) setState(() => _labels.add(name));
    widget.onChanged(_detail.copyWith(label: listed ?? name));
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
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_detail.kind) {
          DetailKind.happening => _happening(context),
          DetailKind.relationship => [
            _who(context),
            const SizedBox(height: 8),
            ..._types(context, 'New relationship type'),
          ],
          DetailKind.anniversary => [
            ..._types(context, 'New anniversary type'),
            _eventDate(context),
          ],
          DetailKind.tag => [
            // Only until Fred makes his first tag.
            if (_labels.isEmpty && (_detail.label?.trim() ?? '').isEmpty) ...[
              const Text(DetailExtrasEditor.noTagsYet),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  DetailExtrasEditor.keepTagsKind,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            ..._types(context, 'New tag'),
            if ((_detail.label?.trim() ?? '').isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  DetailExtrasEditor.needsType,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ..._tagPlaceAndDate(context),
          ],
          DetailKind.fact => const [],
        },
      ),
    );
  }

  /// Date and place side by side, each to change.
  List<Widget> _happening(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final at = _detail.at.toLocal();
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LedgerPickerField(
              label: 'Date',
              value:
                  '${l.formatMediumDate(at)}, '
                  '${l.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
              onTap: _pickHappeningTime,
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(child: _placeField()),
        ],
      ),
    ];
  }

  /// Between two fields in a row.
  static const _gap = 12.0;

  /// The place, to change on the map or clear; "+ place" while there is
  /// none.
  Widget _placeField() {
    final place = _detail.place?.trim() ?? '';
    return LedgerPickerField(
      label: 'Place',
      value: place,
      hint: '+ place',
      onTap: _pickPlace,
      onClear: place.isEmpty
          ? null
          : () => widget.onChanged(_detail.copyWith(place: () => null)),
      clearTooltip: 'Clear the place',
    );
  }

  /// A tag's place and date side by side, "+ place" and "+ date" for what
  /// is not set, and a clear button for what is.
  List<Widget> _tagPlaceAndDate(BuildContext context) {
    final when = _detail.eventDate;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _placeField()),
          const SizedBox(width: _gap),
          Expanded(
            child: LedgerPickerField(
              label: 'Date',
              value: when == null
                  ? ''
                  : MaterialLocalizations.of(context).formatMediumDate(when),
              hint: '+ date',
              onTap: _pickEventDate,
              onClear: when == null
                  ? null
                  : () => widget.onChanged(
                      _detail.copyWith(eventDate: () => null),
                    ),
              clearTooltip: 'Clear the date',
            ),
          ),
        ],
      ),
    ];
  }

  Widget _who(BuildContext context) {
    final others = _others;
    final target = _detail.targetId;
    return DropdownButtonFormField<String>(
      initialValue: others.any((m) => m.id == target) ? target : null,
      isExpanded: true,
      decoration: RememberemTheme.ledgerDecoration(
        Theme.of(context),
        label: 'Who',
      ),
      items: [
        for (final m in others)
          DropdownMenuItem(
            value: m.id,
            child: Row(
              children: [
                PortraitThumb(
                  photo: widget.photoOf(m),
                  size: RememberemTheme.thumbSmall,
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

  /// The type chips, then a "+" that asks for a new type named [title].
  List<Widget> _types(BuildContext context, String title) {
    final chosen = DetailTypeCatalog.normalizeKey(_detail.label ?? '');
    final theme = Theme.of(context);
    return [
      Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final label in _labels)
            ChoiceChip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(label),
              selected: DetailTypeCatalog.normalizeKey(label) == chosen,
              onSelected: (_) =>
                  widget.onChanged(_detail.copyWith(label: label)),
            ),
          ActionChip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            // A shade off the card, like the card off the page.
            backgroundColor: RememberemTheme.shade(
              theme,
              RememberemTheme.raised(theme),
            ),
            avatar: const Icon(Icons.add, size: 18),
            label: const Text(
              'New',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            tooltip: title,
            onPressed: () => _newType(title),
          ),
        ],
      ),
    ];
  }

  /// With no date yet, a pulsing "+ date"; then the date, to change.
  Widget _eventDate(BuildContext context) {
    final when = _detail.eventDate;
    if (when == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: PulsingButton(label: '+ date', onPressed: _pickEventDate),
      );
    }
    return LedgerPickerField(
      label: 'Date',
      value: MaterialLocalizations.of(context).formatMediumDate(when),
      helper: 'When it first happened',
      onTap: _pickEventDate,
    );
  }
}
