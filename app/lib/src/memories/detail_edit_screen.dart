import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../speech/dictated_text_field.dart';
import '../speech/dictation.dart';

/// Adds a detail of one [kind], or changes the extra data of [existing]:
/// a happening's date and place, a relationship's type and person, an
/// anniversary's type and date. Every kind needs a description. Pops with
/// the finished [Detail], or nothing if Fred goes back.
class DetailEditScreen extends StatefulWidget {
  const DetailEditScreen({
    super.key,
    required this.kind,
    required this.ownerId,
    required this.people,
    required this.dictation,
    required this.newId,
    required this.now,
    this.existing,
    this.placeHere,
  });

  final DetailKind kind;

  /// The person the detail is about; never offered as their own relation.
  final String ownerId;

  /// Everyone active (relationship choices) and in the trash too (custom
  /// types still in use).
  final List<Memory> people;
  final Dictation dictation;

  /// The id for a new detail.
  final String newId;

  /// When a new detail is recorded (and a new happening's default date).
  final DateTime now;

  final Detail? existing;

  /// The known place where the phone is now, for a new happening; may
  /// complete late or give nothing.
  final Future<String?>? placeHere;

  @override
  State<DetailEditScreen> createState() => _DetailEditScreenState();
}

class _DetailEditScreenState extends State<DetailEditScreen> {
  late final Detail? _existing = widget.existing;
  late String _text = _existing?.text ?? '';
  late DateTime _at = (_existing?.at ?? widget.now).toLocal();
  late final _place = TextEditingController(text: _existing?.place ?? '');
  late String? _label = _existing?.label;
  late final _customLabel = TextEditingController();

  /// The chosen person; a target now in the trash or gone starts unset,
  /// so Fred picks someone before saving.
  late String? _targetId = _others.any((m) => m.id == _existing?.targetId)
      ? _existing?.targetId
      : null;
  late DateTime? _eventDate = _existing?.eventDate;

  late final List<String> _labels = DetailTypeCatalog.labels(
    widget.kind,
    widget.people,
  );

  List<Memory> get _others => [
    for (final m in widget.people)
      if (m.id != widget.ownerId && m.trashedAt == null) m,
  ];

  @override
  void initState() {
    super.initState();
    if (_existing == null && widget.kind == DetailKind.happening) {
      widget.placeHere?.then((place) {
        // Only fill in a place Fred has not started typing.
        if (mounted && place != null && _place.text.isEmpty) {
          setState(() => _place.text = place);
        }
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _customLabel.dispose();
    super.dispose();
  }

  String get _chosenLabel {
    final typed = _customLabel.text.trim();
    return typed.isNotEmpty ? typed : (_label?.trim() ?? '');
  }

  bool get _complete {
    if (_text.trim().isEmpty) return false;
    return switch (widget.kind) {
      DetailKind.relationship => _chosenLabel.isNotEmpty && _targetId != null,
      DetailKind.anniversary => _chosenLabel.isNotEmpty && _eventDate != null,
      DetailKind.fact || DetailKind.happening => true,
    };
  }

  Detail _build() {
    final kind = widget.kind;
    final place = kind == DetailKind.happening ? _place.text.trim() : null;
    final label = switch (kind) {
      DetailKind.relationship || DetailKind.anniversary => _chosenLabel,
      _ => null,
    };
    final at = kind == DetailKind.happening ? _at : null;
    final existing = _existing;
    if (existing != null) {
      return existing.copyWith(
        text: _text,
        at: at,
        place: place,
        label: label,
        eventDate: _eventDate,
        targetId: () => _targetId,
      );
    }
    return Detail(
      id: widget.newId,
      text: _text,
      at: at ?? widget.now,
      type: kind,
      place: place,
      label: label,
      targetId: kind == DetailKind.relationship ? _targetId : null,
      eventDate: kind == DetailKind.anniversary ? _eventDate : null,
    );
  }

  Future<void> _pickHappeningTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null || !mounted) return;
    setState(
      () => _at = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _pickEventDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? widget.now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted) setState(() => _eventDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'New ${kind.label.toLowerCase()}' : kind.label,
        ),
        actions: [
          TextButton(
            onPressed: _complete
                ? () => Navigator.of(context).pop(_build())
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...switch (kind) {
            DetailKind.happening => _happeningFields(context),
            DetailKind.relationship => _relationshipFields(context),
            DetailKind.anniversary => _anniversaryFields(context),
            DetailKind.fact => const <Widget>[],
          },
          const SizedBox(height: 16),
          DictatedTextField(
            label: 'Description',
            initialValue: _text,
            dictation: widget.dictation,
            multiline: true,
            onChanged: (v) => setState(() => _text = v),
          ),
        ],
      ),
    );
  }

  List<Widget> _happeningFields(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(
          '${l.formatMediumDate(_at)}, '
          '${l.formatTimeOfDay(TimeOfDay.fromDateTime(_at))}',
        ),
        subtitle: const Text('When it happened'),
        onTap: _pickHappeningTime,
      ),
      TextField(
        controller: _place,
        decoration: const InputDecoration(
          labelText: 'Place',
          border: OutlineInputBorder(),
        ),
      ),
    ];
  }

  List<Widget> _labelChooser(BuildContext context, String prompt) => [
    Text(prompt, style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final label in _labels)
          ChoiceChip(
            label: Text(label),
            selected:
                _customLabel.text.trim().isEmpty &&
                DetailTypeCatalog.normalizeKey(label) ==
                    DetailTypeCatalog.normalizeKey(_label ?? ''),
            onSelected: (_) => setState(() {
              _label = label;
              _customLabel.clear();
            }),
          ),
      ],
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _customLabel,
      decoration: const InputDecoration(
        labelText: 'Or type a new one',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    ),
  ];

  List<Widget> _relationshipFields(BuildContext context) {
    final others = _others;
    final label = _chosenLabel;
    final target = others.where((m) => m.id == _targetId).firstOrNull;
    return [
      ..._labelChooser(context, 'Their relationship to this person'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: others.any((m) => m.id == _targetId) ? _targetId : null,
        decoration: const InputDecoration(
          labelText: 'Who',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final m in others)
            DropdownMenuItem(value: m.id, child: Text(m.displayName)),
        ],
        onChanged: (id) => setState(() => _targetId = id),
      ),
      if (label.isNotEmpty && target != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Reads: "My $label is ${target.displayName}"',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  List<Widget> _anniversaryFields(BuildContext context) {
    final when = _eventDate;
    return [
      ..._labelChooser(context, 'What kind'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event),
        title: Text(
          when == null
              ? 'Choose the first date'
              : MaterialLocalizations.of(context).formatMediumDate(when),
        ),
        subtitle: const Text('When it first happened'),
        onTap: _pickEventDate,
      ),
    ];
  }
}
