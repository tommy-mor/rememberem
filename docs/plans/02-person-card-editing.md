# Plan 02: Person card editing

## Goal
On the person card (MemoryEditScreen), Fred sees when each detail was recorded, can delete a detail, and can long-press that time to set any date/time. Name, Place and Meeting are already editable and do not change.

## Acceptance criteria
1. Each saved detail with non-blank text shows its recorded time, in local time, in small text above its text box. The trailing blank row, a row cleared to blank, and any row not yet saved show none.
2. Long-pressing the time opens a date picker, then a time picker. Confirming both shows the new time at once and saves it at once. Cancelling either picker changes nothing.
3. Any date/time may be chosen, including future dates and dates before the photo was taken.
4. Editing a detail's text never changes its time. Changing its time never changes its text.
5. Each saved detail has a delete icon, separate from the text area. Tapping it removes the detail at once and saves at once. A snackbar offers "Undo", which restores the detail with its original id, text and time.
6. A deleted detail stays gone after leaving and reopening the card. A late dictation result or pending text edit for it cannot bring it back.
7. Deleting the last remaining detail leaves one blank box. Deleting an unsaved blank row removes the row and saves nothing.
8. Rows keep their order after any edit, delete or time change. Typed text in other rows is kept.
9. Records already on disk (legacy `details` string, story 1 `detailItems`) load unchanged and their details can be dated and deleted, including the legacy id `<id>-legacy`.

## Design
Data model: no new persisted keys. `Detail.at` is already stored as UTC ISO-8601, so the JSON format is unchanged and old records load as before.

Core, `packages/rememberem_core/lib/src/detail.dart`: `copyWith({String? text, DateTime? at})`, keeping id and UTC normalisation.

`app/lib/src/memories/memory_editor.dart`, the single source of truth:
- `setDetailTime(String id, DateTime at)`: ignores an unknown id; updates the detail in place, keeping list order; marks dirty; `flush()` at once (same as the new-detail path). A private `_flushNow()` does `unawaited(flush().catchError((_) {}))`; setDetailTime, the removal method, restoreDetail and the existing new-detail path in `updateDetail` all use it, so no fire-and-forget flush leaves an unhandled error.
- One removal method, `deleteDetail(String id)`: removes the detail from `_memory` if present, adds the id to a `_deleted` set (saved and blank/unsaved rows alike), marks dirty if anything was removed, and flushes at once. `updateDetail` ignores ids in `_deleted`. The widget calls this for every row it removes, including a blank row and a row dropped when the list empties.
- `restoreDetail(Detail d, int index)`: re-inserts into `_memory.details` (index clamped), removes the id from `_deleted`, flushes. Used by Undo. The widget, not the editor, restores the `_Row` at its old position in the full `_rows` list (blank rows are interleaved, so row index and details index differ); the Undo index is the row index.
- Save failures: `flush()` already survives an earlier failed save (it chains `_lastSave.catchError`), so the permanent stall of baseline risk 3 is gone. Only the rejecting future remains (PopScope awaits flush at pop; dispose flush is unawaited); this story only guarantees its own fire-and-forget calls are quiet.

UI, `app/lib/src/memories/detail_list_editor.dart`: take `details` (from `editor.memory`, not the stale `widget.memory`) plus `onChanged`, `onTimeChanged(id, at)`, `onDelete(id)`, `onRestore(detail, index)`. Rows stay in a non-lazy Column keyed by id. Each saved row shows:
- a header Row with the time in `bodySmall`, wrapped in a long-press GestureDetector with a minimum 48 px high hit area (no extra edit icon; add one only if Fred cannot find the gesture);
- a delete IconButton beside the header, not beside the text box.

The time is formatted with `MaterialLocalizations.formatMediumDate` plus `formatTimeOfDay` (no new dependency; built-in `showDatePicker` then `showTimePicker`), converted `toLocal()`. The pickers start from the detail's current local `at` (`initialDate`/`initialTime`), with `firstDate` 1970-01-01 and `lastDate` 2100-12-31 as the concrete meaning of "any date". The result is combined into a local `DateTime` and passed on; the Detail constructor converts it to UTC. After each `showDatePicker` and `showTimePicker` await, `if (!mounted) return;` runs before `setDetailTime` and `setState` (baseline risk 20 allows `popUntil` during an open dialog).

A row is "saved" when `editor.memory.details` holds a detail with its id and non-blank text; captions are read from `editor.memory.details` by id at build time, not from `widget.memory` or state fixed at initState. Rebuild mechanism: `memory_edit_screen.dart` calls `setState` after setDetailTime, deleteDetail and restoreDetail so captions update at once. The row list is a widget state that mirrors the editor: delete removes the `_Row`, which disposes that field and so stops its dictation. A blank row's delete or removal simply drops it (and still tombstones its id via `deleteDetail`). If the list empties, append a fresh blank row.

Late dictation: `dictated_text_field.dart` `dispose` calls `dictation.stop()` without awaiting, so a final result can arrive afterwards. Add `if (!mounted) return;` at the top of the `onWords` callback so a late result cannot write to the disposed controller or reach `editor.updateDetail`. The tombstone is the second line of defence for the same case.

Undo snackbar lifecycle, `memory_edit_screen.dart`: `memory_edit_screen.dart` shows the Undo snackbar through ScaffoldMessenger, wiring the callbacks to the editor.
- Cache the `ScaffoldMessengerState` in `didChangeDependencies`.
- Clear snackbars in the PopScope pop handler before `navigator.pop`, and best-effort in `dispose` (the shortcut `popUntil` bypasses PopScope). If clearing inside `dispose` misbehaves, defer it.
- The Undo callback must check `mounted` before `restoreDetail` or `setState`. The mounted guard is mandatory (the editor flush in dispose has already run, so a late restore would not be saved); the clearing is the visible half. One mechanism per path, no extra abstraction.

Ordering: insertion order is kept and never re-sorted (the story 8 timeline sorts by `at` itself). Trash (story 3) concerns people, not details, so the details Undo does not conflict with it.

## Tests
Core (`packages/rememberem_core/test/memory_details_test.dart`):
- `copyWith(text:)` keeps `at`; `copyWith(at:)` changes only `at` and stays UTC. (Round-trip and legacy loading are already covered by story 1 tests.)

Editor (`app/test/memory_editor_test.dart`):
- `setDetailTime` then flush: the saved detail has the new `at`, same text and order; a later `updateDetail` keeps that `at`.
- `deleteDetail` saves at once with no `saveDelay` wait; the saved memory lacks the id and neighbours are unchanged.
- After `deleteDetail`, a pending timer and a late `updateDetail(id, 'x')` do not re-create it (assert the last save lacks it).
- `restoreDetail` puts it back at its index with the original `at`. Extended: deleteDetail, restoreDetail, `updateDetail(id, 'new')`, flush, assert the last save holds `'new'` (proves the tombstone is cleared).
- A repository that throws on save causes no unhandled error from delete/time change (via `_flushNow`).
- Legacy id: build a Memory from legacy JSON with only a `details` string and no `detailItems`. `setDetailTime` on `'<id>-legacy'` and assert the time sticks. Then `deleteDetail('<id>-legacy')`, flush, reload via `toJson`/`fromJson` from the repository, and assert `details` is empty.

Widget (`app/test/memory_edit_screen_test.dart`, `detail_list_editor_test.dart`):
- Two details show two time captions; the blank row shows none.
- Long-press, confirm both pickers: the new time is displayed and the last save has that `at` in UTC. Cancelling the date or time picker leaves `at` unchanged.
- Delete the first: only the second text remains, the last save has one detail, and the snackbar Undo restores it in place. The Undo test also types into the restored row and asserts it is saved.
- Delete the only detail: one blank box remains. Delete the blank row: nothing is saved.
- Pop the screen after a delete and reload from the fake repository: the detail is gone and no blank detail was saved.
- Delete, pop, assert no snackbar remains and no exception.
- With the fake dictation: start dictating in a saved row, tap its delete, deliver a final result, then assert the last save lacks the detail and no new detail exists. A second case does the same for an unsaved blank row.

## Risks and mitigations
- Irreversible data loss from a mis-tap: delete icon away from the text, plus Undo snackbar. Leaving the screen clears the snackbar and the Undo callback is guarded by `mounted`, so Undo cannot act on a gone screen (the person's request to forget is honoured).
- Two sources of truth: rows read from the editor; ids are tombstoned in `_deleted`.
- Late async results on a disposed screen (picker awaits, dictation, Undo): `mounted` guards at each, plus tombstone.
- Picker local/UTC shift: convert via `toLocal()` for display and the local `DateTime` for the picker result; tests pin the zone-independent instant.
- Small, hidden long-press target: caption with a 48 px hit area.
- Baseline risk 3 is already mostly fixed in the editor (no stall after a failed save); remaining are the rejecting pop/dispose flush futures, not fixed here.
- Future or pre-capture dates are allowed and must not crash the display.

## Out of scope
Sorting details by date, trash for details or people, deleting a person (story 3), editing `capturedAt`, a confirm dialog, fixing autosave stalls, and any new persisted field.

## Baseline record changes
- Map: Notes, the card shows each detail's local recorded time above it, with a delete icon and long-press time editing.
- Invariant 5: also that an edited `at` round-trips unchanged. Invariant 6: delete and time change save immediately, not after 400 ms.
- Invariant 14: the card also has per-detail time captions and delete icons, still no Save or person-delete button.
- Absent list: "delete of a detail" no longer absent; person delete remains absent (risk 8 stays).
- Risk 3: update to say the stall is already fixed in `MemoryEditor.flush`; only the rejecting pop/dispose flush futures remain.
- Note: details are not re-sorted by `at`.

## Review record
Crews and agents: the slimmed review crew (guardians Rex, Grace, Tess; maintainer Marlin; architect Archie) raised objections; Vera settled them; the neutral plan editor applied the settlement. No TieBreaker was needed.

Objections and settlement:
1. Undo snackbar outlives the card (Rex, Grace): facts favour guardians. Applied: cached ScaffoldMessenger, clear in PopScope handler and best-effort in dispose, mandatory `mounted` check in Undo, widget test.
2. Picker awaits resume on a disposed screen (Rex): agreed. Applied: `mounted` check after each picker await; existing picker tests suffice.
3. Legacy id `<id>-legacy` untested (Tess): agreed. Applied: legacy dating and deleting editor test.
4. Nothing asserts restoreDetail clears the tombstone (Tess): agreed. Applied: extended restore test plus typing in the widget Undo test.
5. Delete mid-dictation and untombstoned blank rows (Grace): facts favour guardians. Applied: single tombstoning removal method used for all rows, `mounted` guard in `onWords`, two widget tests.
6. Keep Undo or drop it (Marlin vs Archie): agreed to keep Undo, with the lifecycle guard; criterion 5 unchanged.

Rulings: none (docs/reviews/rulings/ precedent consulted, no new ruling). Stalemates: none.

Unverified: no builds, tests or devices were run during planning; code references (line numbers, `dictated_text_field.dart` behaviour, whether clearing snackbars inside `dispose` is safe) come from the settlement's evidence and need confirming at implementation. docs/reviews/baseline.md was not re-read by the editor.
