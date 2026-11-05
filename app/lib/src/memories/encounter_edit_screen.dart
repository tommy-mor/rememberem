import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/home_button.dart';
import '../app/ledger_picker_field.dart';
import '../app/portrait_thumb.dart';
import '../app/rememberem_theme.dart';
import '../speech/dictated_text_field.dart';
import 'memory_editor.dart';
import 'when_where_row.dart';

/// One picture of a person: change its place, meeting or date, or delete
/// it. Edits go through the person card's [editor]. Pops with the removed
/// [Encounter] if Fred deletes it.
class EncounterEditScreen extends StatefulWidget {
  const EncounterEditScreen({
    super.key,
    required this.editor,
    required this.services,
    required this.photoFileName,
  });

  final MemoryEditor editor;
  final AppServices services;
  final String photoFileName;

  @override
  State<EncounterEditScreen> createState() => _EncounterEditScreenState();
}

class _EncounterEditScreenState extends State<EncounterEditScreen> {
  MemoryEditor get _editor => widget.editor;

  Encounter? get _encounterOrNull {
    for (final e in _editor.memory.encounters) {
      if (e.photoFileName == widget.photoFileName) return e;
    }
    return null;
  }

  /// Bumped when Remote changes the place, so its field reloads.
  int _placeGen = 0;

  @override
  void dispose() {
    unawaited(_editor.flush().catchError((_) {}));
    super.dispose();
  }

  void _update(Encounter Function(Encounter) change, {bool now = false}) =>
      _editor.updateEncounter(widget.photoFileName, change, now: now);

  void _delete() {
    final removed = _editor.removeEncounter(widget.photoFileName);
    if (removed != null) Navigator.of(context).pop(removed);
  }

  /// Beside the photo: the date and the time, each to change, then the
  /// location with its map pin.
  Widget _whenAndWhere(BuildContext context, Encounter encounter) {
    final localizations = MaterialLocalizations.of(context);
    final local = encounter.capturedAt.toLocal();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerPickerField(
          label: 'Date',
          value: localizations.formatMediumDate(local),
          onTap: () => _pickDate(local),
        ),
        LedgerPickerField(
          label: 'Time',
          value: localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local)),
          onTap: () => _pickClock(local),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                WhenWhereRow.whereOf(encounter),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Change location',
              icon: const Icon(Icons.location_on_outlined, size: 20),
              onPressed: () => WhenWhereRow.pickLocation(
                context,
                widget.services,
                encounter,
                (choice) => setState(() {
                  _update(choice.applyTo, now: true);
                  _placeGen++;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(DateTime local) async {
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(
      () => _update(
        (e) => e.withCapturedAt(
          DateTime(date.year, date.month, date.day, local.hour, local.minute),
        ),
        now: true,
      ),
    );
  }

  Future<void> _pickClock(DateTime local) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null || !mounted) return;
    setState(
      () => _update(
        (e) => e.withCapturedAt(
          DateTime(local.year, local.month, local.day, time.hour, time.minute),
        ),
        now: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final encounter = _encounterOrNull;
    if (encounter == null) {
      // Gone (e.g. deleted elsewhere): nothing left to show here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }
    final isLast = _editor.memory.encounters.length < 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Picture'),
        actions: [
          HomeButton(
            mayLeave: () async {
              // Saved first, so the list shows the latest.
              await _editor.flush().catchError((_) {});
              return true;
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RememberemTheme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PortraitThumb(
                  photo: widget.services.repository.encounterPhoto(encounter),
                  size: RememberemTheme.thumbCard,
                ),
                const SizedBox(width: RememberemTheme.thumbGap),
                Expanded(child: _whenAndWhere(context, encounter)),
              ],
            ),
            const SizedBox(height: 8),
            DictatedTextField(
              key: ValueKey('place-$_placeGen'),
              ledger: true,
              label: MemoryField.place.label,
              initialValue: encounter.place,
              dictation: widget.services.dictation,
              showMic: false,
              onChanged: (v) => _update((e) => e.withPlace(v)),
            ),
            const SizedBox(height: 8),
            DictatedTextField(
              ledger: true,
              label: MemoryField.meeting.label,
              initialValue: encounter.meeting,
              dictation: widget.services.dictation,
              showMic: false,
              onChanged: (v) => _update((e) => e.withMeeting(v)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: isLast ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete picture'),
            ),
            if (isLast)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'A person needs at least one picture.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
