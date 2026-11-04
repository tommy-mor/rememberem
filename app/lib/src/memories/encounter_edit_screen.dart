import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
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
      appBar: AppBar(title: const Text('Picture')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                widget.services.repository.encounterPhoto(encounter),
                height: 320,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const SizedBox(height: 320, child: Icon(Icons.person)),
              ),
            ),
            const SizedBox(height: 8),
            WhenWhereRow(
              encounter: encounter,
              services: widget.services,
              onTimeChanged: (at) => setState(
                () => _update((e) => e.withCapturedAt(at), now: true),
              ),
              onLocationChosen: (choice) => setState(() {
                _update(choice.applyTo, now: true);
                _placeGen++;
              }),
            ),
            const SizedBox(height: 16),
            DictatedTextField(
              key: ValueKey('place-$_placeGen'),
              label: MemoryField.place.label,
              initialValue: encounter.place,
              dictation: widget.services.dictation,
              showMic: false,
              onChanged: (v) => _update((e) => e.withPlace(v)),
            ),
            const SizedBox(height: 16),
            DictatedTextField(
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
