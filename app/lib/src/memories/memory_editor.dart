import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'edit_history.dart';

/// Holds a memory being edited and saves every change shortly after it is
/// made, so nothing needs a Save button. Changes to the fields, details and
/// crop can be undone and redone; listeners hear when that becomes
/// possible.
class MemoryEditor extends ChangeNotifier {
  MemoryEditor(
    this._repository,
    this._memory, {
    this.saveDelay = const Duration(milliseconds: 400),
    this.clock = DateTime.now,
  });

  final MemoryRepository _repository;
  final Duration saveDelay;

  /// Supplies the time stamped on new details.
  final DateTime Function() clock;
  Memory _memory;
  Timer? _timer;
  bool _dirty = false;
  Future<void> _lastSave = Future.value();

  /// Details deleted in this session; late edits to them are ignored.
  final Set<String> _deleted = {};

  /// While closed (during a merge) every change and save is ignored.
  bool _closed = false;

  final EditHistory _history = EditHistory();

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// The newest photo as it is now, known once it is cropped here.
  CardPhoto? _photo;

  CardState get _state => (
    fields: {for (final f in MemoryField.values) f.key: _memory.field(f)},
    details: _memory.details,
    photo: _photo,
  );

  /// Notes the state before a change, for Undo.
  void _record({String? key}) {
    final could = (canUndo, canRedo);
    _history.record(_state, key: key);
    if ((canUndo, canRedo) != could) notifyListeners();
  }

  /// Puts back the fields, details and crop before the last change, and
  /// saves. Returns the photo being written back, or null if the photo is
  /// unchanged. Other pictures, the contact and practice scores are never
  /// touched.
  Future<void>? undo() => _closed ? null : _restore(_history.undo(_state));

  /// Puts back what [undo] took away, and saves; returns as [undo] does.
  Future<void>? redo() => _closed ? null : _restore(_history.redo(_state));

  /// Forgets every Undo step, e.g. on going to another page.
  void clearHistory() {
    // That page may change or remove the newest photo.
    _photo = null;
    if (!canUndo && !canRedo) return;
    _history.clear();
    notifyListeners();
  }

  Future<void>? _restore(CardState? state) {
    if (_closed || state == null) return null;
    var memory = _memory;
    for (final MapEntry(:key, :value) in state.fields.entries) {
      memory = memory.withField(key, value);
    }
    _memory = memory.withDetails(state.details);
    // Details back again take edits again; ones gone ignore late ones.
    final present = {for (final d in state.details) d.id};
    _deleted.removeAll(present);
    _flushNow();
    notifyListeners();
    // Same bytes (by identity: every state shares _photo's record).
    final photo = state.photo;
    if (photo == null || photo == _photo) return null;
    final was = _photo;
    _photo = photo;
    return _repository
        .replaceEncounterPhoto(_memory.id, photo.file, photo.jpeg)
        .catchError((Object error) {
          // Not written: the file still holds what it did.
          _photo = was;
          throw error;
        });
  }

  /// Replaces the photo in [file] with [after], a crop of [before], as one
  /// Undo step.
  Future<void> cropPhoto(
    String file, {
    required List<int> before,
    required List<int> after,
  }) async {
    if (_closed) return;
    await _repository.replaceEncounterPhoto(_memory.id, file, after);
    _photo = (file: file, jpeg: before);
    _record();
    _photo = (file: file, jpeg: after);
  }

  /// The memory as edited, including empty details (just added, or
  /// cleared), which [flush] leaves out of what is saved.
  Memory get memory => _memory;

  void update(String key, String value) {
    if (_closed || _memory.field(_fieldFor(key)) == value) return;
    _record(key: 'field:$key');
    _memory = _memory.withField(key, value);
    _scheduleSave();
  }

  /// Adds [detail] at the end, usually empty for Fred to fill in where it
  /// stands. It is saved once something is entered.
  void addDetail(Detail detail) {
    if (_closed) return;
    if (_memory.details.any((d) => d.id == detail.id)) return;
    _record();
    _memory = _memory.withDetails([..._memory.details, detail]);
    _flushNow();
  }

  /// Puts [detail] in place of the detail with its id (its kind's extra
  /// data was changed) and saves at once. Build it with [Detail.copyWith]
  /// so its score is kept.
  void replaceDetail(Detail detail) {
    if (_closed || _deleted.contains(detail.id)) return;
    final details = _memory.details;
    final index = details.indexWhere((d) => d.id == detail.id);
    if (index == -1 || details[index] == detail) return;
    _record();
    _memory = _memory.withDetails([...details]..[index] = detail);
    _flushNow();
  }

  /// Sets the description of saved detail [id], saved shortly after.
  void updateDetail(String id, String text) {
    if (_closed || _deleted.contains(id)) return;
    final details = _memory.details;
    final index = details.indexWhere((d) => d.id == id);
    if (index == -1) return;
    if (details[index].text == text) return;
    _record(key: 'detail:$id');
    _memory = _memory.withDetails(
      [...details]..[index] = details[index].copyWith(text: text),
    );
    _scheduleSave();
  }

  /// Removes detail [id] (saved or not) and saves at once. Later edits to
  /// it, such as a late dictation result, are ignored until it is restored.
  void deleteDetail(String id) {
    if (_closed) return;
    _deleted.add(id);
    final details = _memory.details;
    if (!details.any((d) => d.id == id)) return;
    _record();
    _memory = _memory.withDetails([
      for (final detail in details)
        if (detail.id != id) detail,
    ]);
    _flushNow();
  }

  /// Puts back a deleted [detail] at [index] (for Undo).
  void restoreDetail(Detail detail, int index) {
    if (_closed) return;
    _deleted.remove(detail.id);
    if (_memory.details.any((d) => d.id == detail.id)) return;
    _record();
    final details = [..._memory.details];
    details.insert(index.clamp(0, details.length), detail);
    _memory = _memory.withDetails(details);
    _flushNow();
  }

  /// Changes the encounter whose photo is [photoFileName]. Date changes
  /// should pass [now] so they save at once; text waits like other edits.
  void updateEncounter(
    String photoFileName,
    Encounter Function(Encounter) change, {
    bool now = false,
  }) {
    if (_closed) return;
    final encounters = _memory.encounters;
    final index = encounters.indexWhere(
      (e) => e.photoFileName == photoFileName,
    );
    if (index == -1) return;
    _memory = _memory.withEncounters(
      [...encounters]..[index] = change(encounters[index]),
    );
    now ? _flushNow() : _scheduleSave();
  }

  /// Removes one encounter and saves at once. Returns it (for Undo), or
  /// null if it is the person's last one, which is never removed.
  Encounter? removeEncounter(String photoFileName) {
    if (_closed || _memory.encounters.length < 2) return null;
    final encounters = _memory.encounters;
    final index = encounters.indexWhere(
      (e) => e.photoFileName == photoFileName,
    );
    if (index == -1) return null;
    _memory = _memory.withEncounters([...encounters]..removeAt(index));
    _flushNow();
    return encounters[index];
  }

  void restoreEncounter(Encounter encounter) {
    if (_closed) return;
    _memory = _memory.withEncounters([..._memory.encounters, encounter]);
    _flushNow();
  }

  /// Stops all changes and saves, e.g. while this person is merged away.
  void close() {
    _timer?.cancel();
    _closed = true;
  }

  /// Undoes [close], e.g. when the merge failed.
  void reopen() => _closed = false;

  MemoryField _fieldFor(String key) =>
      MemoryField.values.firstWhere((f) => f.key == key);

  /// Saves now without waiting. A failure must not surface as an unhandled
  /// error; [flush] marks the state unsaved so the next flush retries it.
  void _flushNow() {
    _dirty = true;
    unawaited(flush().catchError((_) {}));
  }

  void _scheduleSave() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(saveDelay, () => unawaited(flush().catchError((_) {})));
  }

  /// Saves any unsaved change now. Saves run one at a time, in order.
  Future<void> flush() {
    _timer?.cancel();
    if (_dirty && !_closed) {
      _dirty = false;
      final snapshot = _memory.withDetails([
        for (final detail in _memory.details)
          if (!detail.isEmpty) detail,
      ]);
      // A failed earlier save must not block this one; its error has
      // already gone to whoever awaited it.
      _lastSave = _lastSave
          .catchError((_) {})
          .then((_) => _repository.save(snapshot))
          .catchError((Object error) {
            // Not saved: the next flush (e.g. on leaving) tries again.
            _dirty = true;
            throw error;
          });
    }
    return _lastSave;
  }
}
