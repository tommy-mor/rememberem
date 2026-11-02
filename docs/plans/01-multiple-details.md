# Plan 01: Multiple timestamped details

Base commit 89d8d2c. Story: on the notes screen (MemoryEditScreen, "New person") Fred can add more than one detail; each detail records the current time.

## Goal
Replace the single Details string with an ordered list of details, each with text, a stable id and a time. Old records keep loading. The schema is the seam for stories 2, 8 and 11 (edit, delete, timeline, points).

## Acceptance criteria
1. The notes screen shows Name, Place, Meeting, then a Details section with one empty detail box and an "Add detail" button.
2. Tapping "Add detail" adds another empty box below the last, as many times as Fred likes.
3. Each box has its own mic button (labels "Detail", "Detail 2", "Detail 3"...; tooltips "Speak Detail N"). Dictation fills only that box, appended after typed text; starting a new mic ends the previous one.
4. A detail's time is the moment its text first becomes non-blank (`text.trim().isNotEmpty`; a whitespace-only box gets no time and is never saved). With dictation this is the first partial result, i.e. when speech starts. Later typing or dictation into it never changes its time. Autosave and reload never change it.
5. Empty boxes are never saved. Clearing a box removes it from the saved record; typing again in the same box keeps its original time.
6. After leaving and reopening, all non-empty details appear in the order added, with identical text and instants.
7. A record saved by the current build (fields.details = "Likes hiking") loads, shows one detail with that text, and the list screen still loads. Its time is the record's capturedAt.
8. Opening a legacy record and leaving without editing does not change the file.
9. Autosave is unchanged: 400 ms debounce, flush on back, inactive and dispose, no Save button, footer "Saved automatically."
10. Capture and the photo/caption area are unchanged.

## Design

### Core (packages/rememberem_core)
- New `lib/src/detail.dart`: `class Detail { final String id; final String text; final DateTime at; }` with `copyWith(text)`, `toJson`/`fromJson`, value equality. `at` is normalised to UTC; JSON is `{"id","text","at":<UTC ISO-8601 with Z>}`. Story 11 adds optional `points` and `lastCorrectDate` keys later; fromJson ignores unknown keys, so no migration is needed.
- `Memory` gains `final List<Detail> details` (unmodifiable, default `const []`).
- JSON: new top-level key `detailItems` (a list). A list is never written under `fields`; `fields['details']` is no longer written. `fields` stays `Map<String,String>`.
- `Memory.fromJson`: the presence of the `detailItems` key wins over `fields['details']`, even when its list is empty (never test `isEmpty`; test key presence). If the key is present, parse it (no per-entry tolerance; baseline risk 2 stays open). If absent and `fields['details']` is non-blank, produce one `Detail(id: '<memoryId>-legacy', text: that string, at: capturedAt)`. Deterministic, so two loads are equal and ids cannot collide across merged records. In both cases `fromJson` removes the `'details'` key from the parsed `fields` map, and `toJson` never emits it, so the legacy text lives only in `detailItems` after the first save. Nothing is written back until a real edit. A legacy record whose only detail is cleared saves `detailItems: []` and so does not resurrect the legacy text on reload.
- `withField` must carry `details`. Add `withDetails(List<Detail>)`, copying id, photo, capturedAt, location and fields.
- Remove `MemoryField.details` from the enum (`memory_field.dart`) so the field loop no longer renders it; its enum tests (if any) change accordingly.
- Export `detail.dart` from `rememberem_core.dart`.

### App (app/lib/src/memories)
- `MemoryEditor` gets an injected `DateTime Function() clock` (default `DateTime.now`) only. New `updateDetail(String id, String text)`: unknown id with non-blank text appends `Detail(id, text, clock())` and calls `flush()` immediately (one flush site, no special-case save path; it protects only a new detail's existence and time, and the 400 ms window of invariant 6 still applies to later text); known id replaces text only, keeping `at` (including when cleared to blank and retyped), with the normal 400 ms debounce, and is a no-op when the text is unchanged (mirrors the `update` guard); unknown id with blank text does nothing. Blank means `trim().isEmpty` everywhere. `_memory` keeps a cleared detail; `flush` saves `_memory.withDetails(details without blank text)`. Ids are not injected: the row widget creates them from `DateTime.now().microsecondsSinceEpoch.toRadixString(36)`. `update` for name/place/meeting is unchanged.
- New `detail_list_editor.dart` (one class, StatefulWidget): holds row ids (existing detail ids plus one fresh blank id) and each row's initial text, renders the rows in a plain `Column` (not a lazy list, so rows are never disposed off-screen and a live dictation is never stopped) with a multiline `DictatedTextField` per row keyed by `ValueKey(id)` and a per-row `label` ("Detail", "Detail 2"...), and an "Add detail" `TextButton` that appends a fresh blank row id. Calls `onChanged(id, text)` only on a real text change, never when building the blank row, so opening the screen never creates a detail or a save. Neutral hint text, no prompting copy.
- `MemoryEditScreen` renders the Details section through this widget, placed as a Column child within the screen's ListView; nothing else changes. `DictatedTextField` (app/lib/src/speech) keeps its `multiline` parameter and is otherwise untouched.
- No time is displayed in this story (story 2 adds the small date above each detail). It is stored only.

## Tests
Core (`packages/rememberem_core/test`):
- legacy_details_string_loads_as_one_detail: fields {'details':'Likes hiking'} gives exactly one detail, text equal, `at.isAtSameMomentAs(capturedAt)` (not `==`: Dart compares isUtc too), id '<memoryId>-legacy'; two loads equal.
- roundtrip_multiple_details: 3 details with distinct UTC times saved and reloaded via JsonFileMemoryRepository in a temp dir; ids, text, order and instants equal via `isAtSameMomentAs`. Also assert that the raw JSON `at` strings end in `Z`.
- new_shape_ignores_legacy_key: file with both keys uses detailItems only; saved JSON of a migrated record has no fields.details, including after editing only Name on a legacy record and flushing.
- empty_detail_items_beats_legacy_key: fields {'details':'x'} plus `detailItems: []` loads zero details.

App (`app/test`):
- memory_editor_test: updateDetail stamps clock T1 on first non-blank text; a later edit at T2 leaves at == T1; a second detail at T3 has T3; blank text never reaches the repository; two edits inside 400 ms give one save; a new detail is saved immediately.
- memory_editor_test: legacy memory, edit only Name, flush: saved Memory contains the legacy text exactly once, as a detail, and no fields['details']. Also: clearing a detail then retyping keeps its `at`; whitespace-only text creates nothing.
- memory_editor_test (legacy cleared): load a legacy memory, `updateDetail('<memoryId>-legacy', '')`, flush. The saved Memory has no details and no fields['details'], and a reload of that saved JSON also has zero details.
- memory_edit_screen_test: rewrite the existing Details cases (app/test/memory_edit_screen_test.dart: the speakInto 'Details' call, the fields['details'] assertion, `widgetWithText(TextField,'Details')` finders and the 'Speak Details' tooltip) to the new labels, and seed the legacy case through the legacy JSON shape. Also: opening a legacy record and leaving writes nothing (AC8); tapping "Add detail" shows two detail inputs; typing in both and popping saves two details in order; a blank added row is not saved; a legacy memory shows its text in the first box.
- memory_edit_screen_test (mid-dictation add), using the fake Dictation: start dictation in box 1 and emit a partial, tap "Add detail", then emit more words and finish. Assert the words land in box 1 only, box 2 stays empty, and box 1's detail keeps its first-partial time.

Emulator walk (Fred, never Eric's phone):
- Seed a legacy test record via adb run-as. Record sha256 of its `.json` before opening; open it, back out without edits, and confirm the hash matches (AC8). Run on the seeded test person only; record "run" or "not run".
- Probe speech once on the emulator. If it does not work, type the details, mark the dictation leg "Not checked" in the report (covered only by the fake-Dictation widget test), and name a device check for later. Label each detail typed or dictated in the walk log.
- Add three details. Pass leg: force-stop at least 1 s after the last keystroke or partial result, relaunch, confirm all three plus the legacy text.
- Optional second leg: force-stop under 400 ms after editing an existing detail. Log as the known invariant 6 exposure observation, neither pass nor fail.
- Report unrun checks explicitly.
- Z-suffixed ordered instants and no fields.details are covered by the automated core and editor tests against the real JsonFileMemoryRepository in a temp dir, not by the walk.

## Risks and mitigations
- Rollback: an old build reading new files ignores `detailItems`, shows empty Details, and its next save drops `detailItems` entirely. Accepted for a single-user local app. No joined-text mirror in `fields['details']` (it would duplicate text that stories 2 and 3 would have to keep in sync and scrub). Before sideloading an older build, back up the app's documents/memories folder.
- Data loss on conversion: legacy text moves into the list and the legacy key is dropped on first save. Covered by the legacy-not-clobbered and legacy-cleared tests.
- Add then force-stop inside 400 ms (baseline invariant 6): the immediate flush protects only a new detail's existence and time; the 400 ms window of invariant 6 still applies to later text.
- Autosave stall after a failed save (baseline risk 3, `_lastSave.then(...)` at memory_editor.dart:37) is not fixed here. The story adds at most one extra save per new detail and does not change the failure mode. Stays open.
- Timezone: instants stored as UTC with Z; display (story 2) converts to local.
- Dictation `before` capture (baseline risk 11) unchanged; stable row keys stop an added row retargeting a live dictation.

## Out of scope
Editing or deleting details after leaving the screen, showing or editing a detail's date, person card, points and lastCorrectDate, search, merge, and fixing baseline risks 2 to 4.

## Baseline record changes (after this ships)
- Map: record holds name, place, meeting plus timed details (`detailItems`); notes screen shows Name, Place, Meeting, then Details boxes with "Add detail".
- Invariant 5: legacy fields.details loads as one detail timed at capturedAt; detail instants round-trip (tested); presence of `detailItems`, even empty, wins.
- Invariant 6: unchanged apart from a note that a newly created detail is flushed immediately (one flush site, no special-case save path); the 400 ms window still applies to later text.
- Invariant 7: dictation is per detail box.
- Invariant 14: update field order and the Add detail button.
- Risk 2: unchanged and still open (no tolerance added by this story).
- Risk 3: unchanged and still open.
- Risk 18: neutral hint in place; Details can now be many entries.

## Review record
Agents that ran: archie, marlin, owen, gill, rex, hal, pamala, tess, fred (reviewers and builders); vera (settlement); neutral plan editor (this edit). Individual crew composition beyond those named was not visible to the editor.

Objections and settlement:
1. Empty `detailItems` must not resurrect legacy text (tess): facts favour guardians. Added key-presence rule, a core test and a legacy-cleared editor test.
2. "Box 2 mic changes only box 2" test is tautological (tess, gill): facts favour guardians. Replaced with a mid-dictation Add-detail test.
3. Immediate flush worded as "mitigating" invariant 6 (archie, marlin, owen, gill): agreed. Flush kept; wording corrected to protecting only a new detail's existence and time.
4. Fix baseline risk 3 in this story (pamala): facts favour builders. Out of scope; wording clarified; pamala withdrew.
5. Write a joined-text mirror to `fields['details']` (archie, marlin): agreed no mirror; owen's backup line added; suggestion withdrawn.
6. Emulator speech may not work (fred): agreed. Fallback and typed/dictated labelling added.
7. Ambiguous "force-stop within 1 s" (fred): agreed. Reworded into a pass leg (at least 1 s) and an optional observation leg (under 400 ms).
8. Which run-as checks the walk includes (fred, marlin, owen): facts favour builders. One hash check only; other checks stay automated; Z assertion added to the roundtrip test.
9. Duplicated "Add detail TextButton" clause (marlin): agreed. Removed.

Rulings: none. No TieBreaker rulings were issued and no stalemates remained (docs/reviews/rulings/ holds no precedent files at this commit).

Unverified: nothing was built, tested or run during planning. Exact line numbers cited in the settlement (e.g. memory_editor.dart:26-39) and the existing test names in memory_edit_screen_test.dart were taken from the review record, not re-read by the editor. Speech on the emulator and the invariant 6 force-stop exposure are untested.
