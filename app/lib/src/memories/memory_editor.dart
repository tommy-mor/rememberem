import 'dart:async';

import 'package:rememberem_core/rememberem_core.dart';

/// Holds a memory being edited and saves every change shortly after it is
/// made, so nothing needs a Save button.
class MemoryEditor {
  MemoryEditor(
    this._repository,
    this._memory, {
    this.saveDelay = const Duration(milliseconds: 400),
  });

  final MemoryRepository _repository;
  final Duration saveDelay;
  Memory _memory;
  Timer? _timer;
  bool _dirty = false;
  Future<void> _lastSave = Future.value();

  Memory get memory => _memory;

  void update(String key, String value) {
    if (_memory.fields[key] == value) return;
    _memory = _memory.withField(key, value);
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(saveDelay, flush);
  }

  /// Saves any unsaved change now. Saves run one at a time, in order.
  Future<void> flush() {
    _timer?.cancel();
    if (_dirty) {
      _dirty = false;
      final snapshot = _memory;
      _lastSave = _lastSave.then((_) => _repository.save(snapshot));
    }
    return _lastSave;
  }
}
