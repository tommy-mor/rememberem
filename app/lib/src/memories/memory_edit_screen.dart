import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../speech/dictated_text_field.dart';
import 'detail_edit_screen.dart';
import 'detail_list_editor.dart';
import 'encounter_edit_screen.dart';
import 'memory_editor.dart';
import 'memory_tile.dart';
import 'merge_picker_screen.dart';
import 'pictures_section.dart';
import 'when_where_row.dart';

/// The photo of a person with spoken-or-typed notes, saved as you go.
class MemoryEditScreen extends StatefulWidget {
  const MemoryEditScreen({
    super.key,
    required this.memory,
    required this.services,
  });

  final Memory memory;
  final AppServices services;

  MemoryRepository get repository => services.repository;

  @override
  State<MemoryEditScreen> createState() => _MemoryEditScreenState();
}

class _MemoryEditScreenState extends State<MemoryEditScreen> {
  late final MemoryEditor _editor = MemoryEditor(
    widget.repository,
    widget.memory,
  );
  late final AppLifecycleListener _lifecycle;
  // Cached so pending snackbars (detail Undo) can be cleared on leaving.
  ScaffoldMessengerState? _messenger;

  /// Bumped when a picture screen may have changed the newest encounter,
  /// so the Place and Meeting fields reload their text.
  int _fieldsGen = 0;

  /// Everyone active and in the trash, read once on opening: names for
  /// relationships, and the types in use.
  List<Memory> _people = const [];
  Map<String, String> _activeNames = const {};

  /// Set while Back is saving and leaving.
  bool _leaving = false;

  /// Set when leaving via a merge, whose own snackbar must survive.
  bool _keepSnackBars = false;

  /// Reading [_people]; an editor waits for it so its lists are whole.
  late Future<void> _peopleLoaded;

  @override
  void initState() {
    super.initState();
    // Saves straight away if the app is sent to the background.
    _lifecycle = AppLifecycleListener(
      onInactive: () => unawaited(_editor.flush().catchError((_) {})),
    );
    _peopleLoaded = _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final active = await widget.repository.all();
      final trashed = await widget.repository.trashed();
      if (!mounted) return;
      setState(() {
        _people = [...active, ...trashed];
        _activeNames = {for (final m in active) m.id: m.displayName};
      });
    } catch (_) {
      // Names then read as "someone removed" until the card reopens.
    }
  }

  /// The known place nearest to where the phone is now, or null.
  Future<String?> _placeHere() async {
    final at = await widget.services.location.current();
    if (at == null) return null;
    final active = [
      for (final m in _people)
        if (m.trashedAt == null) m,
    ];
    return widget.services.settings.value.placeFinder
        .nearest(at, active)
        ?.place;
  }

  Future<Detail?> _openDetail(DetailKind kind, {Detail? existing}) async {
    await _peopleLoaded;
    if (!mounted) return null;
    final now = _editor.clock();
    return Navigator.of(context).push<Detail>(
      MaterialPageRoute(
        builder: (_) => DetailEditScreen(
          kind: kind,
          ownerId: _editor.memory.id,
          people: _people,
          dictation: widget.services.dictation,
          newId: now.microsecondsSinceEpoch.toRadixString(36),
          now: now,
          existing: existing,
          placeHere: existing == null && kind == DetailKind.happening
              ? _placeHere()
              : null,
        ),
      ),
    );
  }

  Future<void> _addDetail(DetailKind kind) async {
    final detail = await _openDetail(kind);
    if (detail != null && mounted) _edit(() => _editor.addDetail(detail));
  }

  Future<void> _changeDetail(Detail existing) async {
    final detail = await _openDetail(existing.kind, existing: existing);
    if (detail != null && mounted) _edit(() => _editor.replaceDetail(detail));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // Clearing during dispose upsets the messenger, so do it after the
    // frame. (Leaving via a shortcut skips the PopScope handler.)
    final messenger = _messenger;
    if (messenger != null && !_keepSnackBars) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) messenger.clearSnackBars();
      });
    }
    _lifecycle.dispose();
    // Best effort: a failing repository must not raise an unhandled error.
    unawaited(_editor.flush().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Finish saving before leaving, so the list behind shows the latest.
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // Once only: a second Back while saving must not pop another page.
        if (didPop || _leaving) return;
        _leaving = true;
        _messenger?.clearSnackBars();
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context);
        try {
          await _editor.flush();
        } catch (_) {
          // Leave anyway; the edit stays unsaved for the dispose flush.
        }
        if (!mounted) return;
        if (route?.isCurrent != true) {
          // Something opened on top while saving; this Back is dropped
          // (see docs/reviews/rulings/2026-11-01-back-navigation-1.md).
          _leaving = false;
          return;
        }
        navigator.pop();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final memory = _editor.memory;
    return Scaffold(
      appBar: AppBar(title: const Text('New person')),
      // Not a lazy ListView: fields scrolled out of view must keep their
      // text and any dictation in progress.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  widget.repository.photoFile(memory),
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(height: 280, child: Icon(Icons.person)),
                ),
              ),
            ),
            WhenWhereRow(
              encounter: memory.encounters.first,
              services: widget.services,
              onTimeChanged: (at) => _changeNewest((e) => e.withCapturedAt(at)),
              onLocationChosen: (choice) => _changeNewest(choice.applyTo),
            ),
            for (final field in MemoryField.values) ...[
              const SizedBox(height: 16),
              DictatedTextField(
                key: ValueKey('${field.key}-$_fieldsGen'),
                label: field.label,
                initialValue: memory.field(field),
                dictation: widget.services.dictation,
                hint: field == MemoryField.name ? MemoryTile.unknownName : null,
                onChanged: (value) => _editor.update(field.key, value),
              ),
            ],
            const SizedBox(height: 16),
            DetailListEditor(
              details: _editor.memory.details,
              dictation: widget.services.dictation,
              nameOf: (id) => _activeNames[id],
              onChanged: (id, text) =>
                  _edit(() => _editor.updateDetail(id, text)),
              onAdd: _addDetail,
              onEdit: _changeDetail,
              onDelete: (id) => _edit(() => _editor.deleteDetail(id)),
              onRestore: (detail, index) =>
                  _edit(() => _editor.restoreDetail(detail, index)),
            ),
            const SizedBox(height: 16),
            PicturesSection(
              encounters: memory.encounters,
              repository: widget.repository,
              onOpen: _openPicture,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _merge,
              icon: const Icon(Icons.merge),
              label: const Text('Merge with existing person'),
            ),
            const SizedBox(height: 16),
            Text(
              'Saved automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicture(Encounter encounter) async {
    final removed = await Navigator.of(context).push<Encounter>(
      MaterialPageRoute(
        builder: (_) => EncounterEditScreen(
          editor: _editor,
          services: widget.services,
          photoFileName: encounter.photoFileName,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _fieldsGen++);
    if (removed == null) return;
    // Replace, never queue: a queued snackbar dropped on leaving would never
    // close, and its photo would never be deleted.
    final closed = (ScaffoldMessenger.of(context)..hideCurrentSnackBar())
        .showSnackBar(
          SnackBar(
            content: const Text('Picture deleted'),
            // Undo snackbars would otherwise stay until dismissed.
            persist: false,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _editor.restoreEncounter(removed);
                  _fieldsGen++;
                });
              },
            ),
          ),
        )
        .closed;
    // The photo file goes only once Undo is no longer possible.
    if (await closed == SnackBarClosedReason.action) return;
    try {
      await _editor.flush(); // the record must no longer use the photo
    } on Object {
      return; // keep the file while a saved record may still refer to it
    }
    await widget.repository.deleteEncounterPhoto(removed);
  }

  /// Folds this person into one Fred picks, then returns to the list.
  Future<void> _merge() async {
    final target = await Navigator.of(context).push<Memory>(
      MaterialPageRoute(
        builder: (_) => MergePickerScreen(
          repository: widget.repository,
          excludeId: _editor.memory.id,
        ),
      ),
    );
    if (target == null || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Memory merged;
    try {
      await _editor.flush();
      _editor.close();
      merged = await widget.repository.merge(target.id, _editor.memory.id);
    } on Object {
      _editor.reopen();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not finish merging. Try again.')),
      );
      return;
    }
    final oldName = MemoryTile.nameOf(target);
    final newName = MemoryTile.nameOf(merged);
    messenger.clearSnackBars();
    _keepSnackBars = true;
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          oldName == newName
              ? 'Merged into $oldName'
              : 'Merged into $oldName; name now $newName',
        ),
      ),
    );
  }

  /// Changes the picture that represents this person (the newest), saving
  /// at once, and reloads the Place and Meeting fields (Remote sets Place).
  void _changeNewest(Encounter Function(Encounter) change) => setState(() {
    _editor.updateEncounter(
      _editor.memory.encounters.first.photoFileName,
      change,
      now: true,
    );
    _fieldsGen++;
  });

  /// Applies a detail change and rebuilds so time captions stay current.
  void _edit(VoidCallback change) => setState(change);
}
