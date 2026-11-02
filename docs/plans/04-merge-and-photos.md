# Story 4: Merge people and multiple photos

## Goal
After a capture, Fred can merge the new person into an existing one from the notes screen. The existing record survives. A person holds one or more encounters (photo, time, location, place, meeting), and Fred can view, edit and delete them from the person card. Everywhere a single picture stands for a person, it is the newest encounter's photo.

## Acceptance criteria
1. The notes screen has a "Merge with existing person" button. It opens a picker of all other active people (never the current one, never trashed), each row showing newest photo, name or "Unnamed", and place.
2. Picking a person merges at once, with no confirmation, returns to the list, and shows "Merged into <name>". When the survivor's name changed, the snackbar shows the old name: "Merged into <old name>; name now <new>". The new record is gone from the list and from disk.
3. The survivor keeps its id, details and encounters, and gains the new person's encounters (photo, date, location, place, meeting) and details, sorted by time with none lost.
4. The survivor's name changes only if the new person's name is non-blank.
5. The person card has a Pictures section listing encounters newest first (thumbnail, date, place, meeting). Tapping one opens an encounter screen to edit place, meeting and date/time, or delete the picture.
6. Deleting a picture removes it at once with an Undo snackbar. The file is removed only after the snackbar closes without Undo. The last remaining picture cannot be deleted (button disabled, with explanation).
7. The list row, the card header and the picker use the newest encounter's photo. Editing an encounter's date, adding one by merge, or deleting the newest changes it accordingly. The list sorts by the newest encounter's time.
8. Records saved before this story open as one-encounter people with identical photo, date, location, place and meeting, and details still migrate.
9. Pending edits on the notes screen are saved before the merge, and a late autosave afterwards cannot bring back the discarded person or drop merged data.

## Design

### Core (pure Dart)
- New `packages/rememberem_core/lib/src/encounter.dart`: `Encounter {photoFileName, capturedAt, location?, place, meeting}` with `withPlace`, `withMeeting`, `withCapturedAt`, `toJson`, `fromJson`. The photo file name is its identity.
- Ordering rule (one comparator, used everywhere): newest is max `capturedAt`, ties broken by the greater `photoFileName` as a string. Input order is never relied on. The `Memory` constructor sorts encounters newest first with this comparator, `latest` is the first element by the same rule, and the repository's `all()` sorts memories by `latest` using the same comparator (Dart's `List.sort` is not stable, so single-key sorts are nondeterministic on ties).
- `memory.dart`: replace top-level `photoFileName/capturedAt/location` with `List<Encounter> encounters` (1..n, non-empty asserted; sorted per the ordering rule, since date edits legitimately reorder). Getters: `latest` (the one representative rule), plus `capturedAt`, `photoFileName` and `location` delegating to `latest` so existing readers (including memory_edit_screen.dart:146-147) keep compiling. `Memory.field(MemoryField.place/meeting)` reads from `latest`, so stories 5-7 and any missed reader never silently get ''. Methods: `withEncounters`. `fields` keeps only the name. Add `Memory.merged(Memory other)`: the repository first renames the other memory's encounters to their survivor-prefixed photo names, then passes it in. Name from other if non-blank, details unioned by id and sorted by `at`, encounters unioned by photo file name; on a duplicate photo name the survivor's encounter wins (retry is deterministic and keeps post-crash edits).
- `fromJson`: if `encounters` exists, read it. Otherwise build one encounter from legacy `photo`, `capturedAt`, `location`, `fields.place` and `fields.meeting`, removing those two keys from fields. The legacy detail path stays untouched. `toJson` writes `encounters` and no top-level photo keys; legacy top-level keys are not written. There is no downgrade; this is accepted. No store build exists (baseline risk 17: release is debug-signed, nothing has shipped), so only Eric's device is exposed.
- Photo naming: first photo stays `<id>.jpg`. Moved photos become `<survivorId>.<sourcePhotoBase>.jpg` (dots in the base replaced by `_`). The name is deterministic, so a retried merge finds them and does not duplicate. Chained merges (A into B, then B into C) produce chained names; the prefix purge still keeps them. Story 3 purge-by-prefix covers them.
- `memory_repository.dart`: add `Future<Memory> merge(String survivorId, String discardedId)`; `photoFile(Memory)` resolves `latest`; add `File encounterPhoto(Encounter)`; add `Future<void> deleteEncounterPhoto(Encounter)`, which removes only that encounter's jpg. The screen never touches `dart:io`.
- `json_file_memory_repository.dart` (inside story 3's `_serial` chain, read both records from disk):
  1. Throw `StateError` if ids are equal, or either record is missing or trashed.
  2. Copy each discarded photo to its new survivor-prefixed name via temp file plus rename (the existing `_writeAtomically` pattern), skipping a target only if it exists (a truncated copy can never be at the final name). A missing source jpg is skipped: the encounter still moves, and the survivor write and discard proceed (baseline risk 13 allows records whose jpg is gone; the list already has an errorBuilder).
  3. Write the survivor via `_write` with the merged record.
  4. Only then call the private purge on the discarded id.
  A crash between 3 and 4 leaves both people (a duplicate, never a loss). A retry is idempotent. `add()` builds a one-encounter memory. `all()` sorts by the ordering rule above.

### App
- `memory_editor.dart`: `update('place'|'meeting', v)` routes to the latest encounter (no separate setEncounterField), `updateEncounter(photoName, fn)`, `removeEncounter(photoName)` (refuses the last one), `restoreEncounter`, and `close()`, which cancels the timer and turns every mutation (update, updateEncounter, removeEncounter, restoreEncounter) and `flush`, including the screen's dispose flush, into no-ops. `close()` is reversible: `reopen()` makes the editor live again. Whole-snapshot saves stay.
- `memory_edit_screen.dart`: Place and Meeting fields bind to `latest` through the editor (`update`). Add the Merge button and a Pictures section. Merge flow: `await editor.flush()`, `editor.close()`, `repo.merge(...)`, then `popUntil` the list. Failure path: if flush or merge throws, the screen calls `editor.reopen()` so later edits still save, shows a snackbar, and does not strand the user (baseline risk 3, invariant 6). The success snackbar shows the old name when the name changed (AC 2).
- New `merge_picker_screen.dart` (`MergePickerScreen`, takes the repository and the current id) returns the chosen id.
- New `encounter_edit_screen.dart` (`EncounterEditScreen`): takes the card's existing `MemoryEditor` and edits only through it (never its own editor or a repo.save snapshot, which would clobber the card's snapshot): large photo, dictated Place and Meeting, date and time via `showDatePicker/showTimePicker`, and Delete. Delete defers file removal: when the Undo snackbar closes without Undo, the screen calls `repo.deleteEncounterPhoto(encounter)`; with Undo it does not. An orphan jpg after a kill is harmless, as with baseline risk 13.
- `memory_list_screen.dart:93`: use `latest` photo with an `errorBuilder` placeholder. Subtitle place and meeting come from `latest`.
- Update `fake_memory_repository.dart` with `merge` mirroring the rules above, and `deleteEncounterPhoto` recording calls. The fake's merge can be made to throw for tests.

## Delivery slices
(a) Encounter model, legacy load, merge, picker and Merge button, with the legacy-fixture and location/capturedAt round-trip tests. (b) Pictures section, EncounterEditScreen, delete/Undo. Slice (b) can slip alone.
Before first running a build with the new format, copy the device's memories folder as a manual backup (no downgrade, no in-app backup, baseline risk 6). Keep an old-format fixture JSON in core tests permanently.

## Tests
Core (real temp dir):
- Legacy load: old JSON with top-level photo/capturedAt/location, place/meeting fields, and a string `details` loads as one encounter with equal values and a `-legacy` detail. Save then load is equal, and `location` and `capturedAt` are asserted.
- Merge: A keeps id and details. B's name overrides only if non-blank. B's photo bytes exist under A's prefix. `all()` returns only A and B's files are gone. Purging A's old duplicate id never removes A's photos.
- Missing source: a discarded record whose jpg is absent merges; the survivor holds that encounter and nothing is thrown.
- Retry/crash safety (two tests): merge twice with the same pair; and a wrapper that throws after the survivor write and before the discard, then retry yields exactly one copy of each encounter and detail with post-crash survivor edits kept. A pre-existing truncated temp file never lands at a final photo name.
- Chained merge: A into B, then B into C; purging intermediate ids keeps all photos.
- Guards: self-merge, missing id and trashed id throw `StateError` and write nothing. The chain survives.
- Stale save: `save` of a pre-merge B snapshot after the merge throws `StateError` and creates no files. A stale A snapshot is the editor's job (below).
- `latest`: three dates give the newest. Editing a date or removing the newest changes it. A one-encounter memory refuses removal.
- Tie-break: encounters with equal `capturedAt` give the same `latest` and order for both input orders and after a JSON round trip; `all()` orders two such memories identically.
- `deleteEncounterPhoto` removes only that jpg and leaves the person's other photos.

Editor unit:
- `close()` then update is a no-op; `reopen()` then a later update saves.

Widget (fake repo):
- Edit with a pending dictation, tap Merge, pick: flush happens first, the fake sees merge once, and no save of the discarded id follows.
- Merge throws (fake): the editor is reopened and a later edit is saved.
- Merge snackbar shows the old name when the name changed.
- Picker excludes the current and trashed people.
- Pictures section is ordered newest first. Delete shows Undo, which restores. The last picture's Delete is disabled.
- `deleteEncounterPhoto` is called on the fake after the snackbar closes without Undo, and not after Undo.
- List row shows the newest photo after an encounter is added.

## Risks and mitigations
- Stale autosave clobbering a merge: flush, then close the editor, then merge, all inside the serial chain with the discarded id purged. Survivor editors are not open during the flow. If flush or merge throws, `reopen()` restores saving.
- Wrong-person merge is not undoable, because the story demands an automatic merge. Every encounter and detail is kept on the survivor, but the survivor's previous name is overwritten and cannot be recovered in-app. Mitigation: the picker shows photo and name, and the snackbar names the target and, when the name changed, the old name ("Merged into <old name>; name now <new>"). The old name is not stored as a detail or hidden field. The user can delete a wrongly merged picture.
- Per-encounter GPS multiplies exact coordinates (baseline risk 10 grows).
- Format drift is accepted (no downgrade; no store build exists, so only Eric's device is exposed). Corrupt json still hides everyone (risk 2).

## Out of scope
Pixel editing of photos, merge undo or confirmation, merging from the list, auto-fill of place and meeting (5/6), grouping and filtering (7-9), and corrupt-record handling.

## Baseline record changes
- Map: a person is a Memory with 1..n encounters (`<id>.jpg` plus `<id>.<name>.jpg` photos). The repository adds `merge`, `encounterPhoto` and `deleteEncounterPhoto`.
- Invariant 1: each shutter press creates one Memory with one encounter.
- Invariant 14: the notes screen also shows Merge and Pictures. Invariant 15: the list photo and sort use the newest encounter.
- New invariant: merge writes the survivor before discarding, is idempotent, is serialized, and loses no encounter or detail. Legacy files load as one encounter. Tested: yes.
- Risks 8 and 10 get per-photo notes (picture deletion exists; GPS is per encounter).

## Review record
- Crews and agents: the plan crew (Tess, Rex, Grace, Archie, Owen) raised objections; Vera settled them; this neutral editor applied the settlement. No TieBreaker was needed.
- Objections and settlements:
  1. Deferred jpg removal on delete (Archie): kept; added `deleteEncounterPhoto` on the repository, called by the screen after the snackbar closes without Undo; core and widget tests added. Archie withdrew.
  2. Missing source jpg in merge step 2 (Tess): step skips it, encounter still moves; core test added.
  3. Tie-break when `capturedAt` is equal (Tess): single ordering rule (max `capturedAt`, then greater `photoFileName`), shared by constructor, `latest` and `all()`; tie test added.
  4. `editor.close()` stranding a dead editor if merge throws (Rex): `close()` made reversible via `reopen()`, called on flush/merge failure; editor unit test and widget test added.
  5. Risks claimed nothing lost on wrong-person merge (Grace): Risks rewritten, snackbar shows the old name, name is not stored elsewhere.
  6. No-downgrade exposure (Owen): sentence added, no legacy keys written, manual backup and permanent old-format fixture kept.
  7. Wrong-person merge undo and chained-merge test (Owen): no change; undo stays out of scope, chained test already present.
- Rulings: none (docs/reviews/rulings/ holds no files; no stalemates).
- Unverified: no builds, tests or devices were run during planning; line references (memory_edit_screen.dart:146-147, memory_list_screen.dart:93, json_file_memory_repository.dart:80) come from the crew and were not re-checked here; story 3 behavior (`_serial`, purge-by-prefix, `save()` refusing purged ids) is assumed as planned.
