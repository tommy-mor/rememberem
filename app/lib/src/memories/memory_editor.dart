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
    final details = _memory.details;
    final index = details.indexWhere((d) => d.id == id);
    if (index == -1) {
      if (text.trim().isEmpty) return;
      _memory = _memory.withDetails([
        ...details,
        Detail(id: id, text: text, at: clock()),
      ]);
      _dirty = true;
      flush();
      return;
    }
    if (details[index].text == text) return;
    _memory = _memory.withDetails(
      [...details]..[index] = details[index].copyWith(text: text),
    );
    _scheduleSave();
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
          .then((_) => _repository.save(snapshot));
    }
    return _lastSave;
  }
}
