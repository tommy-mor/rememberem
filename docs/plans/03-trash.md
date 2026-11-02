# Story 3: Trash and purge

## Goal
Fred can move a person to the trash from the main list, later open the trash, and permanently purge a person there as a separate, confirmed action. Purge removes the photo and record from app-private storage for good (baseline risk 8).

## Acceptance criteria
1. Each row on the main list has a "Move to trash" button. Tapping it removes the row at once and shows a snackbar "Moved <name or Unnamed> to trash" with Undo.
2. Undo returns the person to the list in its newest-first position with every field, detail, location and photo unchanged.
3. A trashed person never appears in the main list, including after an app restart.
4. The list app bar has a Trash button that opens the Trash screen. It lists trashed people (most recently trashed first) with name, place, meeting and photo. An empty trash shows "Trash is empty."
5. Each trash row has Restore and "Delete forever". Restore returns the person to the main list.
6. "Delete forever" opens a dialog naming the person ("Delete <name> forever? The photo and notes cannot be recovered.") with Cancel and Delete. Cancel changes nothing. Delete removes the row.
7. After purge, no file for that person remains in the memories folder (photo, record or `.tmp`). Other people are untouched.
8. Trashing never deletes any file. There is no auto-purge and no "empty trash" button.
9. Records saved before this story load as active people.
10. A trashed person cannot be opened in the notes screen. A late autosave can neither untrash a person nor recreate a purged one.

## Design

### Data model (core, pure Dart)
- `memory.dart`: add nullable `DateTime? trashedAt`. `toJson` writes `'trashedAt'` only when non-null; `fromJson` reads it if present, so old files load as active. `_copy` carries it. Add `Memory withTrashedAt(DateTime? at)`. Story 2 edits this file too (details), so touch only the new field, constructor parameter and `_copy`, and expect a trivial merge.
- Storage layout is unchanged: still `<id>.json` plus `<id>.jpg`.

### Repository (`memory_repository.dart`, `json_file_memory_repository.dart`)
New interface methods:
- `Future<List<Memory>> all()` now returns active people only, newest first. This is the single filter point for every later story (matching, games, metric, map, timeline).
- `Future<List<Memory>> trashed()` returns trashed people, most recently trashed first.
- `Future<void> trash(String id, DateTime at)` and `Future<void> restore(String id)`. Each reads the on-disk record, sets or clears `trashedAt` and writes atomically. Working from disk by id avoids stale in-memory copies. A missing id throws `StateError`.
- One private `_update(id, fn)` helper (read json, apply fn, atomic write, `StateError` if the record is missing) backs `trash`, `restore` and `save`, so the missing-id rule lives in one place.
- All five mutations (`add`, `save`, `trash`, `restore`, `purge`) are serialized through one private helper in `JsonFileMemoryRepository`: `Future<T> _serial<T>(Future<T> Function() op) { final r = _tail.then((_) => op()); _tail = r.catchError((_) {}); return r; }`. The caller sees its own error (for example `StateError` on a purged or missing id) and the chain continues, so one rejected link cannot poison later mutations (baseline risk 3). This also means the guard's read-then-write cannot interleave with a trash, closing the race where a slow, unawaited dispose flush (risk 20) reads the record as active, loses to `trash()`, then writes `trashedAt = null`. Reads (`all`, `trashed`) are not in the chain.
- `Future<void> purge(String id)`. Deletes every file in the folder whose basename (not full path) starts with `"$id."` (jpg, any later photos, `.tmp` siblings), skipping the `.json`, then deletes `<id>.json` last. It lists by id and does not parse the record, so a corrupt json cannot block it. Missing files are fine, so a second call does not throw and a half-finished purge can be retried.
- `save(Memory)` now reads the existing `<id>.json` first. If it is missing (purged), it throws `StateError` and creates nothing. Otherwise it writes the memory with the on-disk `trashedAt`, so a stale copy cannot untrash. `add()` uses a private `_write` for the first write. The extra read per autosave is acceptable.
- Private `_loadAll()` shared by `all()` and `trashed()`; partition on `trashedAt`. The corrupt-json behaviour (risk 2) is unchanged and out of scope.

### App
- `memory_list_screen.dart`: trailing `IconButton(Icons.delete_outline, tooltip: 'Move to trash')` per row, with no swipe gesture. On tap, remove the row from the local list at once, call `trash`, show the snackbar, then reload in the background (do not swap the FutureBuilder future, which would flash a spinner). Undo calls `restore` and reloads. Each reload starts only after the awaited trash, restore or purge future completes. The screen keeps a private int `_reloadGen`; a reload captures the current value when it starts and applies its result only if that value is still current. AppBar action `Icons.delete`, `tooltip: 'Trash'`, pushes TrashScreen. The existing didPopNext reload handles return.
- New `trash_screen.dart` (`TrashScreen`, takes `MemoryRepository`): FutureBuilder over `trashed()`, rows with Restore and Delete forever. Reloads after each awaited action completes, using the same private `_reloadGen` guard (apply a reload result only if its captured generation is still current).
- New `purge_confirm_dialog.dart` (`confirmPurge(context, name)` returning bool).
- Trash rows are not tappable, so the edit screen is unreachable for trashed people.
- Update the app's test fake repository (`app/test/fakes/fake_memory_repository.dart`) to mirror the new semantics: a thin `Map<String, Memory>`, `all()` filters out trashed, `trashed()` sorts by `trashedAt`, `save()` throws `StateError` for a purged id, and `purge` calls are recorded. Otherwise the "row disappears" tests could pass for the wrong reason.

## Tests
Core (real temp dir):
- Round-trip: add with name, detail, location and capturedAt, then trash. `all()` omits it, `trashed()` returns it, and `toJson` matches the original except `trashedAt`. Photo bytes are unchanged. Restore reverses it.
- Legacy: JSON without `trashedAt` loads with `trashedAt == null` and appears in `all()`.
- Purge: with two people, plant `<id>.jpg.tmp`, purge one. The folder has no file starting with that id and the other's two files remain. A second purge does not throw.
- Corrupt purge: overwrite the json with garbage, then purge still removes everything.
- Stale save: build the stale `Memory` before the trash call (so its `trashedAt` is null), trash, then `save(staleMemory)`. Assert `trashedAt` on disk is still set. The person stays in `trashed()` and not in `all()`. Purge, then `save` throws and the folder has no file for that id.
- Order: `trashed()` is sorted by `trashedAt` descending.
- Prefix: purge a person whose id is a string prefix of another's id; the other's files remain.
- Race (deterministic): a test-only subclass or wrapper delays the first read; unawaited `save`, then `trash`; the person ends trashed. Confirm the test fails with the chain removed. No production hook is added.
- Chain survives failure: `save` on a purged id throws, then `add` and `trash` on other people still succeed and their files are on disk.

Widget (fake repo):
- Find the row trash button and the app bar Trash button by tooltip.
- Tap trash on a row: the row disappears, the snackbar shows, Undo restores the row.
- Trash screen: Restore moves the row out; Delete forever then Cancel leaves `purge` uncalled; then Delete calls `purge` once with the id.
- Empty trash shows the empty text.
- Reload ordering (list screen): a fake whose `all()` can be delayed; trash, Undo, then complete the first reload last. The restored row must still show.
- Reload ordering (Trash screen): the same check with a delayed `trashed()`.

Manual (device, once): trash, restart, restore, trash, purge, and check the folder via `adb`.

## Risks and mitigations
- Stale-write resurrection: handled by the `save` guard, serialized mutations, and no edit route to trashed people. The dispose flush (risk 20) could throw on a purged id, but purge is only reachable from the trash screen, so wrap nothing new here.
- Accidental purge: separate screen, named confirm, no bulk action.
- Story 4 multi-photo and merge: purge deletes by id prefix, so extra photos named `<id>.*` are covered. Story 4 must keep that naming or update `purge` (one place). A merge must also respect `all()` filtering.
- Corrupt json hides trash too (risk 2 persists).
- Trashed people stay on disk and in backups (risk 6) until purged. Noted in the baseline only; no extra UI copy.

## Out of scope
Auto-expiry, empty-all, bulk select, swipe gestures, search in trash, error handling for corrupt records, undo for purge, merge and multi-photo.

## Baseline record changes
- Map: the repository has add, save, all (active only), trashed, trash, restore, purge and photoFile.
- Remove "no delete" from "Absent from the code". Risk 8 is resolved: purge removes the photo, record and `.tmp` files, by id.
- New invariant: all() returns active people only; trashing is reversible and deletes nothing; purge deletes by id, record last, and is idempotent; save never recreates a purged person nor untrashes. Tested: yes.
- Invariant 14 and 15: the list has a trash button per row and an app bar Trash entry; the notes screen is unreachable for trashed people.
- Invariant 5: record round-trip now asserted for location and capturedAt.
- Risk 6: note that trashed people remain in backups until purged.

## Review record

**Crews and agents:** Archie (plan author side), Tess (test/robustness critic), Sally and Grace (supporting reviewers), Owen (reviewer), Vera (settlement). Neutral plan editor applied the settlement. TieBreaker was not needed.

**Objections and settlement**
1. Tess: the serialized mutation chain was silent on failure, so one rejected link could poison later mutations (baseline risk 3). Agreed. The Repository section now specifies the `_serial` helper that swallows errors on the tail only, plus a "Chain survives failure" core test.
2. Tess: reloads after trash, Undo, Restore and Delete were outside the chain and could land out of order. Agreed. Each screen keeps a private `_reloadGen` and applies only the current reload; reloads start after the awaited action. Reads stay out of the repository chain. Two widget tests added (list and Trash screen).
3. Tess: the Race and Stale-save tests could pass for the wrong reason. Agreed. Race is deterministic via a test-only subclass or wrapper and must fail with the chain removed; Stale save builds the stale Memory before trashing and asserts on-disk `trashedAt`. No production hook.
4. Sally's concessions (no purge-prefix collision guard because ids are base36 joined by '-' and contain no dots; no backup UI copy; no wrapping of the dispose flush because purge is reachable only from the Trash screen). Agreed, no plan change.

**Rulings:** none (no stalemates). No files in docs/reviews/rulings/ were added for this story.

**Unverified:** nothing was built, run or tested during planning. The id-format claim (json_file_memory_repository.dart:64-66) comes from Sally's evidence in the settlement and was not rechecked. The merge with story 2's edits to `memory.dart` is expected to be trivial but not confirmed.
