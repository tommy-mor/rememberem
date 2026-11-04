import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rememberem_core/rememberem_core.dart';

import '../app/app_services.dart';
import '../app/home_button.dart';
import '../contacts/contact_link_button.dart';
import '../maps/location_choice.dart';
import '../maps/location_picker_screen.dart';
import '../speech/dictated_text_field.dart';
import '../trash/purge_confirm_dialog.dart';
import 'crop_screen.dart';
import 'detail_list_editor.dart';
import 'encounter_edit_screen.dart';
import 'memory_editor.dart';
import 'memory_tile.dart';
import 'merge_picker_screen.dart';
import 'person_card_route.dart';
import 'pictures_section.dart';
import 'relationships_section.dart';
import 'when_where_row.dart';

/// The photo of a person with spoken-or-typed notes, saved as you go.
class MemoryEditScreen extends StatefulWidget {
  const MemoryEditScreen({
    super.key,
    required this.memory,
    required this.services,
    this.justMet = false,
  });

  final Memory memory;
  final AppServices services;

  /// Just photographed: offers to delete them at once, in case they would
  /// rather not be remembered.
  final bool justMet;

  static const askedText = 'Only keep people who are happy to be remembered.';

  MemoryRepository get repository => services.repository;

  @override
  State<MemoryEditScreen> createState() => _MemoryEditScreenState();
}

class _MemoryEditScreenState extends State<MemoryEditScreen> {
  /// The route of each person's page that is open, so following a
  /// relationship back to someone already open returns to that page
  /// instead of opening a second editor (which would save a stale copy).
  static final Map<String, Route<dynamic>> _openPages = {};
  late final MemoryEditor _editor = MemoryEditor(
    widget.repository,
    widget.memory,
  );
  late final AppLifecycleListener _lifecycle;
  // Cached so pending snackbars (detail Undo) can be cleared on leaving.
  ScaffoldMessengerState? _messenger;

  /// Bumped when a picture screen may have changed the newest encounter,
  /// or Undo or Redo changed the fields, so the fields reload their text.
  int _fieldsGen = 0;

  /// Bumped by Undo and Redo, so the detail rows reload their text.
  int _detailsGen = 0;

  /// The fields (by key, or "details") whose dictation is listening;
  /// Undo and Redo wait until none is, so late words land nowhere stale.
  final Set<String> _dictating = {};

  /// Everyone active and in the trash, read once on opening: names for
  /// relationships, and the types in use.
  List<Memory> _people = const [];
  Map<String, String> _activeNames = const {};

  /// Set while Back is saving and leaving.
  bool _leaving = false;

  /// Set when leaving via a merge, whose own snackbar must survive.
  bool _keepSnackBars = false;

  /// Set while a crop is being saved.
  bool _cropping = false;

  /// This page's route, kept for [dispose], where it cannot be looked up.
  Route<dynamic>? _route;

  /// Bumped after a crop, so the photo is read again from its file.
  int _photoGen = 0;

  /// Places found for new happenings, applied only once Fred writes
  /// something, so a row he abandons is still empty and never saved.
  final Map<String, String> _suggestedPlaces = {};

  @override
  void initState() {
    super.initState();
    // Saves straight away if the app is sent to the background.
    _lifecycle = AppLifecycleListener(
      onInactive: () => unawaited(_editor.flush().catchError((_) {})),
    );
    unawaited(_loadPeople());
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

  /// [_people] with this person as edited so far, so a type made on this
  /// card is offered for the next detail.
  List<Memory> get _peopleNow {
    final me = _editor.memory;
    return [
      for (final m in _people) m.id == me.id ? me : m,
      if (!_people.any((m) => m.id == me.id)) me,
    ];
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

  /// Adds an empty row of [kind] to fill in where it stands. A new
  /// happening's place is filled in from where the phone is, unless Fred
  /// has typed one first.
  void _addDetail(DetailKind kind) {
    final now = _editor.clock();
    final detail = Detail(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      text: '',
      at: now,
      type: kind,
    );
    _edit(() => _editor.addDetail(detail));
    if (kind != DetailKind.happening) return;
    _placeHere().then((place) {
      if (!mounted || place == null) return;
      final current = _editor.memory.details
          .where((d) => d.id == detail.id)
          .firstOrNull;
      if (current == null || (current.place?.trim() ?? '').isNotEmpty) return;
      if (current.text.trim().isEmpty) {
        _suggestedPlaces[detail.id] = place;
      } else {
        _edit(
          () => _editor.replaceDetail(current.copyWith(place: () => place)),
        );
      }
    }, onError: (_) {});
  }

  /// A description typed into row [id]: saved, with any place suggested
  /// for it while it was still empty.
  void _describe(String id, String text) => _edit(() {
    _editor.updateDetail(id, text);
    final place = _suggestedPlaces[id];
    if (place == null || text.trim().isEmpty) return;
    _suggestedPlaces.remove(id);
    final current = _editor.memory.details.where((d) => d.id == id).firstOrNull;
    if (current != null && (current.place?.trim() ?? '').isEmpty) {
      _editor.replaceDetail(current.copyWith(place: () => place));
    }
  });

  /// Opens someone this person is related to, after saving this page; on
  /// coming back, everyone is read again (that page may have changed them).
  Future<void> _openRelated(Memory other) async {
    final navigator = Navigator.of(context);
    // Another page: what could be undone here is left behind.
    _editor.clearHistory();
    if (_openPages[other.id] case final open?) {
      // Already open further back: return there (pages above it save as
      // they close).
      navigator.popUntil((route) => route == open);
      return;
    }
    try {
      await _editor.flush();
    } catch (_) {
      // Still open them; the edit stays queued for the next flush.
    }
    final fresh = (await widget.repository.all())
        .where((m) => m.id == other.id)
        .firstOrNull;
    if (fresh == null || !mounted) return;
    await navigator.push(
      PersonCardRoute(services: widget.services, memory: fresh),
    );
    if (mounted) await _loadPeople();
  }

  /// Crops the picture that represents this person, replacing its file.
  Future<void> _crop() async {
    if (_cropping) return;
    final memory = _editor.memory;
    final photo = widget.repository.photoFile(memory);
    final messenger = ScaffoldMessenger.of(context);
    final Uint8List jpeg;
    try {
      jpeg = await photo.readAsBytes();
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('This photo cannot be opened.')),
      );
      return;
    }
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropScreen(jpeg: jpeg)),
    );
    if (cropped == null || !mounted) return;
    setState(() => _cropping = true);
    try {
      await _editor.flush();
      await widget.repository.replaceEncounterPhoto(
        memory.id,
        memory.latest.photoFileName,
        cropped,
      );
      // Every screen shows the photo from the same file name.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      if (mounted) setState(() => _photoGen++);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the crop. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    _route ??= ModalRoute.of(context);
    if (_route case final route?) {
      // The newest page wins; a closing one removes only its own entry.
      _openPages[widget.memory.id] = route;
    }
  }

  @override
  void dispose() {
    if (_openPages[widget.memory.id] == _route) {
      _openPages.remove(widget.memory.id);
    }
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

  /// Home saves first, so the list shows the latest.
  Future<bool> _saveBeforeLeaving() async {
    // Already leaving (Back, trash or delete): that finishes the job.
    if (_leaving) return false;
    try {
      await _editor.flush();
    } catch (_) {
      // Leave anyway; the edit stays queued for the dispose flush.
    }
    return true;
  }

  Widget _buildScaffold(BuildContext context) {
    final memory = _editor.memory;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(memory.displayName, overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              tooltip: 'Move to trash',
              icon: const Icon(Icons.delete_outline),
              onPressed: _trash,
            ),
          ],
        ),
        actions: [
          HomeButton(mayLeave: _saveBeforeLeaving),
          if (widget.services.contacts case final contacts?)
            ContactLinkButton(
              memoryId: memory.id,
              initialKey: memory.contactKey,
              contacts: contacts,
              repository: widget.repository,
            ),
        ],
      ),
      // Not a lazy ListView: fields scrolled out of view must keep their
      // text and any dictation in progress.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _photo(memory),
                const SizedBox(width: 12),
                Expanded(child: _photoGroup(context, memory)),
              ],
            ),
            if (widget.justMet) _askedRow(context),
            if (memory.encounters.length > 1)
              PicturesSection(
                encounters: memory.encounters.skip(1).toList(),
                repository: widget.repository,
                onOpen: _openPicture,
              ),
            for (final field in MemoryField.values) ...[
              const SizedBox(height: 16),
              DictatedTextField(
                key: ValueKey('${field.key}-$_fieldsGen'),
                label: field.label,
                initialValue: memory.field(field),
                dictation: widget.services.dictation,
                // Speaking is for the moment of meeting; later, typing.
                showMic: widget.justMet,
                hint: switch (field) {
                  MemoryField.name => MemoryTile.unknownName,
                  MemoryField.place => 'unknown',
                  _ => null,
                },
                onListeningChanged: (listening) =>
                    _setDictating(field.key, listening),
                onChanged: (value) {
                  _editor.update(field.key, value);
                  // The title shows the name as it is typed.
                  if (field == MemoryField.name) setState(() {});
                },
              ),
            ],
            const SizedBox(height: 16),
            _scaledForDetails(
              context,
              DetailListEditor(
                details: _editor.memory.details,
                dictation: widget.services.dictation,
                ownerId: memory.id,
                people: _peopleNow,
                photoOf: widget.repository.photoFile,
                choosePlace: _choosePlace,
                nameOf: (id) => _activeNames[id],
                onChanged: _describe,
                onReplace: (detail) =>
                    _edit(() => _editor.replaceDetail(detail)),
                onAdd: _addDetail,
                onDelete: (id) => _edit(() => _editor.deleteDetail(id)),
                onRestore: (detail, index) =>
                    _edit(() => _editor.restoreDetail(detail, index)),
                generation: _detailsGen,
                onListeningChanged: (listening) =>
                    _setDictating('details', listening),
              ),
            ),
            const SizedBox(height: 16),
            RelationshipsSection(
              person: memory,
              people: _peopleNow,
              photoOf: widget.repository.photoFile,
              onOpen: _openRelated,
            ),
            const SizedBox(height: 16),
            _undoRow(context),
          ],
        ),
      ),
    );
  }

  /// The photo that represents this person; tap it to open its picture
  /// page. The crop button sits on its lower right corner.
  Widget _photo(Memory memory) {
    return SizedBox(
      width: 192,
      height: 240,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _openPicture(memory.encounters.first),
              child: Tooltip(
                message: 'Open this picture',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.repository.photoFile(memory),
                    key: ValueKey('photo-$_photoGen'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.person),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: IconButton.filledTonal(
              tooltip: 'Crop',
              icon: const Icon(Icons.crop),
              onPressed: _cropping ? null : _crop,
            ),
          ),
        ],
      ),
    );
  }

  /// Beside the photo: Merge, then when and where it was taken.
  Widget _photoGroup(BuildContext context, Memory memory) {
    final label = Theme.of(context).textTheme.labelLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            textStyle: label?.copyWith(fontSize: (label.fontSize ?? 14) * 0.6),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: _merge,
          icon: const Icon(Icons.merge, size: 16),
          label: const Text(
            'Merge with existing person record',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        WhenWhereRow(
          stacked: true,
          encounter: memory.encounters.first,
          services: widget.services,
          onTimeChanged: (at) => _changeNewest((e) => e.withCapturedAt(at)),
          onLocationChosen: (choice) => _changeNewest(choice.applyTo),
        ),
      ],
    );
  }

  /// A happening's place, from the map: a known place's pin, or a spot
  /// Fred names. Null if he went back.
  Future<String?> _choosePlace(String current) async {
    final choice = await Navigator.of(context).push<LocationChoice>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          services: widget.services,
          initial: null,
          initialPlace: current,
          askName: true,
        ),
      ),
    );
    return choice?.place;
  }

  Widget _askedRow(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            MemoryEditScreen.askedText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(onPressed: _deleteNow, child: const Text('Delete now')),
      ],
    ),
  );

  /// Deletes this person for good, not to the trash, after asking: they
  /// said no after the photo was taken.
  Future<void> _deleteNow() async {
    if (_leaving) return;
    final memory = _editor.memory;
    final name = MemoryTile.nameOf(memory);
    if (!await PurgeConfirmDialog.show(context, name)) return;
    if (!mounted || _leaving) return;
    _leaving = true;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final route = ModalRoute.of(context);
    try {
      await _editor.flush();
      _editor.close();
      await widget.repository.trash(memory.id, _editor.clock());
    } on Object {
      _editor.reopen();
      _leaving = false;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete. Try again.")),
      );
      return;
    }
    var deleted = true;
    try {
      await widget.repository.purge(memory.id);
    } on Object {
      deleted = false;
    }
    if (!mounted) return;
    messenger.clearSnackBars();
    _keepSnackBars = true;
    // This page, even if another was opened over it meanwhile.
    if (route != null && !route.isCurrent) {
      navigator.removeRoute(route);
    } else {
      navigator.pop();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Deleted $name.'
              : "Moved $name to the trash, but couldn't delete. "
                    'Empty it from the Trash.',
        ),
      ),
    );
  }

  /// Saves, moves this person to the trash and goes back, offering Undo,
  /// which brings them back and opens them again.
  Future<void> _trash() async {
    // Once only, and not while Back is already leaving.
    if (_leaving) return;
    _leaving = true;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final memory = _editor.memory;
    try {
      await _editor.flush();
      _editor.close();
      await widget.repository.trash(memory.id, _editor.clock());
    } on Object {
      _editor.reopen();
      _leaving = false;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not move to trash. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    messenger.clearSnackBars();
    _keepSnackBars = true;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Moved ${memory.displayName} to trash'),
        // Undo snackbars would otherwise stay until dismissed.
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await widget.repository.restore(memory.id);
              final back = (await widget.repository.all())
                  .where((m) => m.id == memory.id)
                  .firstOrNull;
              if (back == null) return;
              await navigator.push(
                PersonCardRoute(services: widget.services, memory: back),
              );
            } on StateError {
              // Already deleted for good from the Trash screen.
            } on Object {
              messenger.showSnackBar(
                const SnackBar(content: Text('Could not undo. Try the Trash.')),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _openPicture(Encounter encounter) async {
    _editor.clearHistory();
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
    _editor.clearHistory();
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
    // Undo covers the fields as typed, not a map or time choice; after
    // one, older steps would put back a stale place.
    _editor.clearHistory();
    _editor.updateEncounter(
      _editor.memory.encounters.first.photoFileName,
      change,
      now: true,
    );
    _fieldsGen++;
  });

  /// Detail text at Fred's chosen size, on top of the phone's own.
  Widget _scaledForDetails(BuildContext context, Widget child) {
    final percent = widget.services.settings.value.detailTextPercent;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        // Sampled at body size, where Android's nonlinear scaling is
        // nearest to what Fred sees.
        textScaler: TextScaler.linear(
          media.textScaler.scale(14) / 14 * percent / 100,
        ),
      ),
      child: child,
    );
  }

  /// Applies a detail change and rebuilds so time captions stay current.
  void _edit(VoidCallback change) => setState(change);

  void _setDictating(String key, bool listening) {
    if (!mounted) return;
    setState(() => listening ? _dictating.add(key) : _dictating.remove(key));
  }

  /// Undo or Redo, then every field and row reads its text again.
  void _step(VoidCallback step) => setState(() {
    step();
    _fieldsGen++;
    _detailsGen++;
  });

  /// Small Undo and Redo buttons either side of "Saved automatically.".
  Widget _undoRow(BuildContext context) => ListenableBuilder(
    listenable: _editor,
    builder: (context, _) {
      final idle = _dictating.isEmpty;
      return Row(
        children: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: idle && _editor.canUndo
                ? () => _step(_editor.undo)
                : null,
          ),
          Expanded(
            child: Text(
              'Saved automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: idle && _editor.canRedo
                ? () => _step(_editor.redo)
                : null,
          ),
        ],
      );
    },
  );
}
