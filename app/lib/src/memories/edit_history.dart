import 'package:rememberem_core/rememberem_core.dart';

/// What Undo and Redo put back on a person's card: its fields (name, place
/// and meeting, by key), its details, and once it has been cropped, the
/// newest photo (its file and JPEG bytes; null leaves the photo as it is).
typedef CardState = ({
  Map<String, String> fields,
  List<Detail> details,
  CardPhoto? photo,
});

/// A photo file's bytes, as Undo or Redo puts them back.
typedef CardPhoto = ({String file, List<int> jpeg});

/// The card's Undo and Redo steps. Typing into one field (or one detail's
/// description) makes a single step until something else is changed.
class EditHistory {
  final List<CardState> _undo = [];
  final List<CardState> _redo = [];

  /// The field being typed into, whose run of changes is one step.
  String? _run;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Notes [before], the state a change is about to replace. A new change
  /// ends any Redo. Changes in a row with the same [key] are one step.
  void record(CardState before, {String? key}) {
    if (key != null && key == _run) return;
    _undo.add(before);
    _redo.clear();
    _run = key;
  }

  /// The state to put back in place of [current], or null if none.
  CardState? undo(CardState current) {
    if (_undo.isEmpty) return null;
    _run = null;
    _redo.add(current);
    return _undo.removeLast();
  }

  /// The state undone last, to put back in place of [current], or null.
  CardState? redo(CardState current) {
    if (_redo.isEmpty) return null;
    _run = null;
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _run = null;
  }
}
