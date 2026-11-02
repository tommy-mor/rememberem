import 'dart:async';

import 'package:rememberem_core/rememberem_core.dart';

/// Holds a memory being edited and saves every change shortly after it is
/// made, so nothing needs a Save button.
class MemoryEditor {
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

  /// The memory as edited, including details cleared to blank (which
  /// [flush] leaves out of what is saved).
  Memory get memory => _memory;

  void update(String key, String value) {
    if (_memory.fields[key] == value) return;
    _memory = _memory.withField(key, value);
    _scheduleSave();
  }

  /// Sets the text of detail [id]. A new detail is stamped with the time
  /// its text first becomes non-blank and saved straight away; later edits
  /// keep that time.
  void updateDetail(String id, String text) {
    if (_deleted.contains(id)) return;
    final details = _memory.details;
    final index = details.indexWhere((d) => d.id == id);
    if (index == -1) {
      if (text.trim().isEmpty) return;
      _memory = _memory.withDetails([
        ...details,
        Detail(id: id, text: text, at: clock()),
      ]);
      _flushNow();
      return;
    }
    if (details[index].text == text) return;
    _memory = _memory.withDetails(
      [...details]..[index] = details[index].copyWith(text: text),
    );
    _scheduleSave();
  }

  /// Changes when detail [id] was recorded, keeping its text and place.
  void setDetailTime(String id, DateTime at) {
    final details = _memory.details;
    final index = details.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _memory = _memory.withDetails(
      [...details]..[index] = details[index].copyWith(at: at),
    );
    _flushNow();
  }

  /// Removes detail [id] (saved or not) and saves at once. Later edits to
  /// it, such as a late dictation result, are ignored until it is restored.
  void deleteDetail(String id) {
    _deleted.add(id);
    final details = _memory.details;
    if (!details.any((d) => d.id == id)) return;
    _memory = _memory.withDetails([
      for (final detail in details)
        if (detail.id != id) detail,
    ]);
    _flushNow();
  }

  /// Puts back a deleted [detail] at [index] (for Undo).
  void restoreDetail(Detail detail, int index) {
    _deleted.remove(detail.id);
    final details = [..._memory.details];
    details.insert(index.clamp(0, details.length), detail);
    _memory = _memory.withDetails(details);
    _flushNow();
  }

  /// Saves now without waiting. A failure must not surface as an unhandled
  /// error; [flush] marks the state unsaved so the next flush retries it.
  void _flushNow() {
    _dirty = true;
    unawaited(flush().catchError((_) {}));
  }

  void _scheduleSave() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(saveDelay, flush);
  }

  /// Saves any unsaved change now. Saves run one at a time, in order.
  Future<void> flush() {
    _timer?.cancel();
    if (_dirty) {
      _dirty = false;
      final snapshot = _memory.withDetails([
        for (final detail in _memory.details)
          if (detail.text.trim().isNotEmpty) detail,
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
