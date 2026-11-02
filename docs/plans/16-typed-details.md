# Story 16: Typed details (fact, happening, relationship, anniversary)

## Goal
Every detail has a type and a required description. Happenings carry a date and place, relationships point at another person, anniversaries carry a type and first date, and facts carry nothing extra. Quizzes show the type and extra data and never offer two correct choices.

## Acceptance criteria
1. A new person's card shows no empty detail row, only four buttons: "+ fact", "+ happening", "+ relationship", "+ anniversary". Each opens the matching input UI.
2. A detail with a blank description is never saved, for any type.
3. Happening: date defaults to now and place to the current-location place (best effort, blank on failure). Both are editable.
4. Relationship: choose a type chip (coworker, partner, spouse, friend, boss) or type a new one, and pick another active person. Pointing Fred at Jill with "boss" means Jill is Fred's boss. The picker excludes Fred.
5. Anniversary: choose a type (first met, wedding, birthday, started work, lost someone) or type a new one, and pick the date of the first event.
6. A custom type appears in later suggestion lists while any person (active or trashed) has a detail using it. It disappears when the last use is deleted or purged. "Mentor" and "mentor " count as one type.
7. Each detail row shows its type in small text in the upper-left. The description is prefixed: happening "date, place"; relationship "My boss is Jill"; anniversary "Wedding, 3 Jun 2010". A fact has no prefix.
8. Renaming Jill updates how Fred's relationship reads. If Jill is trashed, the row reads "My boss is someone removed", the detail is not quizzed or reminded, and restoring Jill brings the link back. If Jill is purged, her id is cleared from every other record (label and text kept), the row reads "My boss is someone removed" for good, and the detail is not quizzed. The purge confirmation says that other people's relationships to her will lose the link.
9. After merging Jill into Jane, Fred's detail points at Jane. A relationship that would point at its own owner is removed.
10. Details recorded before this story load as facts and keep id, text, time and scores. They leave the timeline. Opening a record writes nothing, and a legacy detail saved after an unrelated edit is byte-compatible with before (no `type` key).
11. Facts never appear on the timeline. Happenings appear on their own date. Anniversaries and relationships do not appear.
12. A detail quiz turn shows the type, the extra data and the description. A relationship turn reads "My boss is Jill" and the correct choice is the owner (the person who has the detail), as for every other type. Every turn has exactly one correct choice.
13. Points and lastCorrectDate survive any edit of description, date, place, label or target, and survive a stale autosave. (`save()` protects scores only; type and target fields are protected because only one card is open at a time and the editor closes during a merge.)
14. Bad or unknown data in the new keys never hides a record (see Core, `detail.dart`).

## Design
**Core (pure Dart), `packages/rememberem_core/lib/src/`**
- `detail_kind.dart`: `enum DetailKind { fact, happening, relationship, anniversary }`.
- `detail.dart`: add `kind` (default fact), `place`, `targetId`, `label` and `eventDate` (all nullable). JSON keys: `type`, `place`, `targetId`, `label`, `eventDate`, each omitted when unset. `type` is written only for happening, relationship and anniversary; a fact never writes it, so a legacy detail saved after an unrelated edit keeps its old bytes. `eventDate` is a 'YYYY-MM-DD' string, so there is no timezone shift. `text` is always written, so an older app still loads the file. `at` stays the recorded time and is also the happening's date. `copyWith` and `withScore` carry every field. A missing `type` loads as fact. Type is fixed after creation (no type change UI).
  - **Caveat:** omitting `type` keeps legacy bytes unchanged but does NOT make legacy facts distinguishable from facts created in this version (both are type-less with an `at`). A later rule such as "treat old facts as placeless happenings" would hit new facts too. Whether old details leave the timeline is therefore **Eric to approve now**, not something to defer on the assumption of an easy later fix.
  - **Defensive parsing:** `Detail.fromJson` parses the new keys defensively and degrades each bad field alone, keeping id, text, at and scores: an unknown or non-string `type` becomes fact, an unparseable `eventDate` becomes null, a non-string `targetId`, `label` or `place` becomes null. It must not throw on these (today's hard casts at `detail.dart:13-21` do, and `_loadAll` has no per-file guard, so one throw would hide every memory).
  - **Incomplete typed details:** a relationship with a missing/unresolvable target reads "My [label] is someone removed" (label missing reads "Relationship"); an anniversary with a missing label or date shows "Anniversary" and omits the missing part. The planner drops any relationship without a resolvable active target and any anniversary missing label or date (not quizzed or reminded).
- `detail_type_catalog.dart` (`DetailTypeCatalog`): the default lists for relationship and anniversary, plus custom labels derived by scanning `all()` and `trashed()` (both reads). It is computed once per picker open, not per keystroke. Keys are trimmed and case-folded by a `normalizeKey` function on the catalog (no separate file), and the first-seen spelling is shown. Nothing is stored.
- `detail_prompt.dart` (`DetailPrompt`): builds the type caption, prefix and "My boss is" text from a detail and a name resolver, shared by the card and the game. It is also the single source of the planner's equivalence key.
- `detail_quiz_planner.dart`: the answer stays the OWNER for every type, so `DetailPair`, scoring by detail id and reminder logic are unchanged. `eligible()` drops a relationship whose target is not active, is absent (purged) or is the owner, drops incomplete anniversaries, and drops any pair for which another active person holds a detail with the same equivalence key. The key is built for all four kinds from the rendered `DetailPrompt` output (kind, normalised label, resolved target NAME, date, place, text), not from `targetId`: two different active people both named Jill, each the target of a same-label same-text relationship, would otherwise produce identical prompts with two correct answers. Because equivalent pairs are ineligible, `choicesFor` stays "any 3 other active people" and every turn has exactly one correct choice. The check is deterministic (no Random) and linear per pair, so `canPlay` (list button, game, ReminderTarget with its Random(0) planner) is unchanged in shape. A pair also needs at least 3 other active people. The turn shows the owner as the answer; the prompt reads "My boss is Jill".
- `timeline_builder.dart`: only `kind == happening` details are mapped. The "recorded" stand-in (today `details.isEmpty`) becomes "no happening details", so a person with only facts, relationships or anniversaries (every migrated record) still appears once.
- `json_file_memory_repository.dart`: one private method retargets an id to a survivor id or to null across active and trashed records, writing only changed files. It uses its own tolerant scan (reads the directory, skips corrupt json files, never throws on them). It must NOT be built on `_loadAll()`, which has no per-file guard (`:224-233`), because purge must still work on a corrupt record (purge at `:110-117` and `_isActive` at `:190-199` deliberately allow it). Idempotent, so a retry is safe, and it runs inside the existing serial chain.
  - `merge`: after writing the survivor and before `_deleteFiles(discardedId)`, call it to retarget discarded to survivor; relationships on the survivor or others that would now point at their own owner are dropped.
  - `purge`: after the trashed-only check and before `_deleteFiles`, call it to retarget the purged id to null (clear only `targetId`; keep label and text). A crash before the delete leaves a trashed, retriable record.
  - Trash and restore keep the link.
  - `FakeMemoryRepository` gets identical merge and purge behaviour.

**App**
- `memory_editor.dart`: `addDetail(Detail)` (rejects blank text, saves at once). `updateDetail` keeps its tombstone logic and accepts a whole replacement `Detail` (built with `copyWith`, so scores are kept). No separate field-edit method.
- `detail_list_editor.dart`: per-kind row widgets, the four add buttons, per-detail dictation by id, and delete with Undo for all types. Long-press re-dating stays for happenings. One new file, `detail_edit_sheet.dart`: a sheet per kind (chip input with typed custom label, person picker, date and place) that commits a whole `Detail`.
- Purge confirmation text (trash screen) gains the line about relationships losing the link.
- Name resolution: the card loads `repository.all()` (active only) once on open into an id-to-name map passed to `DetailPrompt`; the game already holds the people list.
- Happening place default: `AppSettings.placeFinder` with the device location. Failure leaves it blank.
- `detail_game_screen.dart`: render the prompt through `DetailPrompt`; correctness and scoring are unchanged (owner, detail id).

## Tests
- Core, detail round-trip: JSON with no `type` loads as fact. Fields from `fields['details']` load as fact. Points and lastCorrectDate are kept. Opening writes nothing. A legacy detail saved after an unrelated edit has no `type` key and keeps id, text, `at` and scores. A fact never writes `type`; the other three do.
- Core, bad-data fixtures: unknown `type`, non-string `type`, garbage `eventDate`, and wrong-typed `targetId`/`label`/`place` each load without throwing, degrade only that field, and keep id, text, at and scores. A memory containing one is still returned by `all()`.
- Repository: a game result is on disk, an editor save changes the label, the target and the text, and the stored points are kept.
- Repository: rename, trash and restore Jill keep Fred's link. After a purge, Fred loads with `targetId` cleared, label and text kept, and the row reads "someone removed". After a merge into Jane, Fred points at Jane. A self-reference is removed.
- Repository purge: crash between the remap write and the file delete, then retry, is correct; a trashed record pointing at the purged person is cleared; a corrupt json file is skipped and purge of a corrupt trashed record still works; only changed files are written. Same cases on the fake.
- Catalog: a custom type appears while any non-purged person uses it, vanishes after the last delete or purge, and "Mentor" and "mentor " give one entry.
- Planner property test with random seeds over all four types, with duplicate texts, dates and targets. Each turn has exactly one correct choice. A pair with an equivalent detail on another active person is skipped, including an owner with two same-label relationships and two owners pointing at the same target with the same label. With fewer than 3 other active people `canPlay` is false.
- Planner, same-name targets: two distinct active people sharing a name, each the target of a same-label same-text relationship held by different owners, assert neither pair is eligible.
- Planner and ReminderTarget, unresolved targets: a relationship whose target is trashed, absent (purged) or equal to the owner yields no `DetailPair` and cannot be chosen by `canPlay` or `ReminderTarget`; restoring the target makes it eligible again.
- Timeline: a fact makes no dated entry, a happening lands on its date, and anniversaries and relationships make none. A person with only facts still appears once as "recorded".
- Merge: crash between survivor write and discard delete, then retry, is correct; a trashed record pointing at the discarded person is remapped; a corrupt json file is skipped. Same cases on the fake.
- Widget: a new person shows four buttons and no empty row. A blank description is not saved. Row captions and prefixes show per type, including "someone removed" for an unresolved target. The game shows "My boss is Jill" and the owner tile is correct. The purge confirmation mentions relationships.
- Integration: add one detail of each type on a device, restart the app, and confirm they persist.

## Risks and mitigations
- Old details leaving the timeline is a visible change. Migrating them to happenings would invent places. It is a presentation change, not data loss: `at` and text stay on disk. **Eric to approve** (and see the distinguishability caveat under `detail.dart`).
- Downgrade or rollback: an older build's `toJson` writes only id, text, at and scores, so after typed details exist it silently drops type, label, targetId, eventDate and place on its next save of that record. No unknown-key preservation (YAGNI). Added to the pre-deployment checklist: no build older than this story may be installed over data written by this one.
- Relationship direction: the card reads "My boss is Jill"; the quiz asks who says it (answer = owner). Covered by the relationship test and `DetailPrompt`.
- Merge and purge remaps touch several files without a transaction. Both are idempotent, run before the destructive delete, and are retriable like the existing merge.
- Purge now rewrites other people's records (clears `targetId`). Corrupt files are skipped, not repaired.
- Sensitive types such as "lost someone": quiz and reminder wording stays generic, and notifications are unchanged (they name no one). The `grace` review is needed.
- `save()` keeps only scores by id. A stale editor copy could write back an old type or target, but only one card is open at a time and the editor closes during a merge. Not traced further; a test covers the merge case.

## Out of scope
Changing a detail's type, a one-tap "make this a happening" for legacy details, the reverse relationship view from Jill's side, showing happening places on the Places map, a contacts link (story 17, which gets its own field and does not reuse `targetId`), and relationship graph screens.

## Baseline record changes
Add a "Story 16" entry covering: `Detail.kind` and its fields, a missing or unknown type loads as fact, `type` is omitted for facts, bad new-key data degrades per field, and nothing is written on open. Targets are ids resolved against active people at read time; merge remaps them to the survivor and purge clears them (tolerant scan, before the delete). Custom types are derived and never stored. The planner's equivalence key is built from the rendered prompt (resolved name, not id) and ensures one correct choice. Facts, anniversaries and relationships are off the timeline. Update the Story 1 "details" and Story 8 timeline entries (details no longer all map to encounters), and the purge entry (purge now clears relationship targets in other records).

## Review record
**Crews that ran:** Plan check (builders: archie, marlin and one other builder) and Baseline (guardians including tess, owen, grace), one round of rebuttals each way, settled by `vera`. No stalemates, so the TieBreaker crew (`paige`, `walt`, `hazel`) did not run and no rulings were issued (`docs/reviews/rulings/` unchanged).

**Objections and settlement (all agreed):**
1. tess: relationship uniqueness keyed on `targetId` while the prompt shows the name, so two people named Jill give identical prompts. Settled: key from the rendered prompt for all kinds; same-name planner test added.
2. tess: no tests for trashed, purged, missing or self targets in quiz and reminders. Settled: planner and ReminderTarget tests added, including return after restore.
3. grace: purge left a dead `targetId` in other records. Settled: shared remap method, purge calls it with null before delete; must use a tolerant scan, not `_loadAll()`; merge and purge crash, trashed and corrupt-file tests; criterion 8 and purge wording updated.
4. owen: migration irreversible if `type` written on next save. Settled: omit `type` for facts, round-trip test, distinguishability caveat stated, timeline loss stays "Eric to approve".
5. owen: forward and bad-data tolerance untested. Settled: defensive `fromJson`, three fixture tests, incomplete-detail behaviour defined.
6. owen: downgrade flattens typed details. Settled: stated risk and deployment checklist item; no unknown-key preservation.
7. tess/owen vs archie/marlin: one-tap "make this a happening". Settled: archie withdrew; type stays fixed; out of scope.
8. marlin: merge remap is non-transactional. Settled: already covered; remap stays before the delete and uses the tolerant scan.

**Unverified / open:** Eric's approval that old details leave the timeline. The `grace` sensitivity review of "lost someone" wording. No builds, tests or devices were run during planning; line references (`json_file_memory_repository.dart`, `detail.dart`) are from the reviewers' reading at commit 33be280 and were not re-checked by the editor. Privacy questions listed in CLAUDE.md are unchanged by this story.
