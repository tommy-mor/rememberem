# Story 11: Details practice game

## Goal
Fred can start a ten-turn game from the main list. Each turn shows one detail he wrote for 3 s, then four photos with names. He taps until he finds the person the detail is about. First-try-correct gives that detail a point and a lastCorrectDate; any wrong tap resets its points to zero. Later games prefer weak or stale details.

## Acceptance criteria
1. The list has a "Practice details" control beside "Practice faces". It is enabled only when at least 4 active people exist and at least one active person has a detail with non-blank text. Otherwise it is disabled with a line: "Add a detail and have 4 people to practice."
2. A game has exactly 10 turns, then a gentle finish ("Done, N of 10 right first try") with a Back to list button. No streaks or shaming text.
3. Each turn shows only the detail text for 3 s. No photo, name or choice is visible then.
4. After 3 s the detail text is gone and 4 cards appear, each a photo with a name underneath ("Unnamed" if blank): the subject plus 3 other distinct active people. Cards are distinct by person id, so two people named Sarah are two cards, and only the subject's card is correct.
5. Card order is shuffled and unrelated to the answer. A wrong tap greys that card; Fred keeps picking until correct, then the next turn starts.
6. First-try-correct: that detail's points +1 and lastCorrectDate = now (UTC), saved.
7. Any wrong tap: that detail's points become 0 at once (saved even if Fred quits). lastCorrectDate is untouched. A later correct tap earns nothing.
8. Later games prefer details with low points and old or never-correct dates. The same detail is never picked in consecutive turns when 2 or more are eligible.
9. Scores survive editing detail text, re-dating, trashing, restoring, merging, and the card editor's late whole-record save.
10. Inactive (shade, permission dialog): the detail text is hidden behind a neutral placeholder and the timer cancelled; no scoring. Resume restarts the full 3 s reveal. Paused or hidden ends the game. The text is never in Semantics or tooltips outside reveal.
11. A person or detail vanishing mid-game never crashes and never earns a false point. Existing files load with 0/null and opening never rewrites them.

## Design
Data (`packages/rememberem_core/lib/src/detail.dart`): add `int points` (0) and `DateTime? lastCorrectDate` (UTC) to `Detail`. `fromJson` reads both with defaults (unknown keys already ignored). `toJson` emits each only when non-default, so old files stay byte-identical. The constructor normalises `lastCorrectDate?.toUtc()` (as it does `at`), and `==` compares it null-safely with `isAtSameMomentAs`. `copyWith` gains both and carries them by default (text edit and re-date keep the score). `==` and `hashCode` include both. `memory.dart`: add `Memory.withDetailScores(List<Detail> onDisk)`, which returns the record with, for each detail whose id is also on disk, the disk points and date taken wholesale per detail id. The doc comment pins the rule: no max(), no non-default-wins logic, so a stale null date never clears a non-null disk date and a stale higher score never overrides a disk reset. Details with no disk counterpart (newly added in the editor) keep their own values. It never adds or revives details. Points and lastCorrectDate follow the detail id across text edits and re-dating, deliberately: the editor autosaves on every debounced edit, and a reset would zero a score on each typo fix. Cost: a detail rewritten into something different keeps its old score; the wrong-answer reset and the date weighting limit that cost. `merged` already unions details by id (survivor wins); scores travel with the Detail, so no change beyond a comment.

Repository (`memory_repository.dart`, `json_file_memory_repository.dart`, `app/test/fakes/fake_memory_repository.dart`):
- `Future<void> recordDetailAnswer(String memoryId, String detailId, {required bool correctFirstTry, required DateTime at})` via `_serial`/`_update`. Throws StateError if the person is purged or the detail id is absent, and also if the person is trashed, checked inside the `_update` change callback by throwing when `onDisk.trashedAt != null`. Do not call `_readActive`: it does a separate read outside `_update`, a second read in the serial chain. Changes only that detail's points and date: correct is +1 and date=at; otherwise points=0 and date untouched.
- `save()` becomes `memory.withTrashedAt(disk.trashedAt).withScore(disk).withDetailScores(disk.details)` (story 10 adds `withScore`; both hooks sit on this one line). The fake mirrors both.
- Delete then Undo: the deleted detail is gone from disk, so Undo re-adds the editor's in-memory object with its old score. Accepted and tested.

Core:
- `practice_weight.dart`: top-level `double practiceWeight(int points, DateTime? last, DateTime now)` = 1/(1+points) + min(daysSince,60)/30, null = 60 days. If story 10 already exposes the weight as a pure top-level function, import it. If it is private or inline, write `practiceWeight` here and change `FaceQuizPlanner` to call it in a one-line edit, the only edit to story 10 files. The build must not depend on a larger extraction. Nothing else is shared.
- `detail_quiz_planner.dart`: `DetailQuizPlanner(Random, DateTime Function() clock)`.
  - `typedef DetailPair = ({Memory person, Detail detail});` lives in this file (no separate class or file).
  - `eligible(List<Memory>)` returns `DetailPair`s for active people with non-blank detail text.
  - `canPlay(List<Memory>)` is true with at least 4 active people and at least one pair. This is the one definition for the list control and the in-game end check.
  - `pickNext(pairs, {String? previousDetailId})` makes a weighted draw over pairs, because per-person-first would starve a stale detail. It excludes the previous detail id when 2 or more pairs exist.
  - `choicesFor(person, activePeople)` returns the subject plus 3 randomly chosen distinct-id active decoys, shuffled with the injected Random. Same-name decoys are allowed.

App: `app/lib/src/practice/detail_game_screen.dart`. It is a copy of the face screen's structure, not an abstraction (phases reveal, choose, finished; injected repo, planner and `Duration reveal`; AppBar close).
- Each turn re-reads `repo.all()` in try/catch. A read error or `!canPlay` ends the game with a message.
- At most one `recordDetailAnswer` per turn (first wrong tap or clean first-try correct). The handler awaits it, catches any exception, and advances with no point. Taps are ignored while pending.
- `mounted` and `_ended` checks follow every await. One Timer, cancelled in dispose and on inactive. Resume restarts the full 3 s. Paused or hidden ends the game.
- Photos use `repo.photoFile` with an `errorBuilder` placeholder. Each card's Semantics label is the displayed name only; the photo `Image` has `excludeFromSemantics`. The detail text is in the tree (and Semantics) only during the reveal phase.
- `memory_list_screen.dart`: add the second control in the same bottom `SafeArea` row as story 10's, enabled by `canPlay`; reload on `didPopNext`. The control derives `canPlay` from the list already loaded in the list screen's `_reload`, with no second `all()` call. The builder re-checks this against the landed story 8-10 version of the file.

## Tests
- Detail JSON: a story-10 detail loads 0/null; default `toJson` has no new keys; points 3 with a UTC date round-trips equal; `copyWith(text:)` and `copyWith(at:)` keep the score; `==` distinguishes points.
- Merge: survivor's detail wins on an id clash; the discarded person's unique details keep their scores; merging twice is a no-op. Trash and restore keep scores.
- Repository: after `recordDetailAnswer` makes D 4 points, `save()` of a stale Memory with D's text edited and a new detail keeps D at 4 with the new text and the new detail at 0; reverse order the same. One combined test: a stale save keeps both a person score (story 10) and a detail score. Reset direction: D has 4 points and a date; load a stale Memory; `recordDetailAnswer(false)` leaves disk at 0 with the date unchanged; then `save()` the stale copy with D's text edited; assert D has 0 points, the unchanged disk date and the new text. Also assert a stale null date does not clear a non-null disk date. A detail deleted by the editor stays deleted. `recordDetailAnswer` on a trashed person, purged person, or missing detail throws StateError without writing, and touches no other detail.
- Weight: `practiceWeight(0, null)` > `practiceWeight(5, today)`, positive and finite. Face planner tests still pass. Detail with a local-time `lastCorrectDate` round-trips equal.
- Planner: pairs exclude blank text and trashed people; a person with one old detail is still drawn; the previous detail is never repeated with 2 or more pairs; `canPlay` is false with 3 people; `choicesFor` yields 4 distinct ids including the subject; two Sarahs are distinct-id choices; across seeds the correct index is not constant.
- Widget (fakeAsync, fake repo, seeded Random): detail text visible at 2.9 s and no cards; at 3.0 s text gone and 4 cards; text absent while inactive and absent from the choose-phase tree and Semantics (one assertion that `find.text(detail)` matches nothing plus a semantics-tree search, in both the choose phase and the inactive placeholder; no separate tooltip/Semantics test, as the plan adds no tooltip); wrong then right leaves 0 and the date unchanged with one write; from 4 points a wrong tap gives 0; first-try gives +1 and clock date; 10 turns then the finish; a throwing `recordDetailAnswer` reaches the finish with no point; a detail deleted mid-game is skipped; dispose with a held Completer leaves no timer or write and taps are blocked while that write is pending; paused ends the game.
- List: control disabled with the message at 3 people or with no details; enabled otherwise; no overlap with the FAB.
- Integration: smoke-launch with 4 people, play one turn, then delete test data.

## Risks and mitigations
- Late editor save reverts scores (baseline risk 20): `save()` takes disk scores per id; tested both orders.
- Sensitive note on screen or in the app switcher (risk 16): hidden on inactive, game ends on paused, excluded from Semantics outside reveal, never in logs or error text.
- Answer leaks through card order: shuffled by the seeded Random; ids, not names, identify choices.
- Fewer than 4 people or a corrupt file (risk 2): game disabled or ends with a message, never spins.
- Deleted detail mid-game: StateError caught, turn advances, no false point.
- Story 10's two known pitfalls (missing mounted/_ended guards, shortened reveal after resume) are avoided here.

## Out of scope
Showing points on cards, the 5+ metric (12), back-navigation work (13), reminders (14), a shared game base class, per-game history, difficulty settings.

## Baseline record changes
Add "Story 11: details practice". `Detail` has `points` and `lastCorrectDate`, omitted at default, kept by copyWith, merge (survivor wins) and trash/restore. Scores change only through serialized `recordDetailAnswer`; `save()` preserves them per detail id and never revives deleted details. Add `DetailQuizPlanner`, `practiceWeight` (shared with the face planner) and `DetailGameScreen` to the Map. The list has a "Practice details" control. Note the game hides detail text on inactive and ends on paused/hidden, and that risk 16 remains open for the rest of the app. Update the tests line.

## Review record
- Process: neutral plan editor applied Vera's settlement to the draft plan. No further crews or agents ran in this step. TieBreaker rulings: none (docs/reviews/rulings/ precedent not invoked; rulings list empty). Stalemates: none.
- Settled objections:
  1. Trashed-person refusal in `recordDetailAnswer`: agreed. Kept StateError, thrown inside the `_update` callback (not `_readActive`); screen keeps catching per turn. Archie withdrew his challenge.
  2. Tess: save() tests cover only the stale-lower direction: facts favoured the guardians. Added the reset-direction test, null-date assertion and the wholesale-per-id rule in the `withDetailScores` comment, including that details with no disk counterpart keep their own values.
  3. canPlay reuse: agreed. Control uses the list already loaded in `_reload`, no second `all()`.
  4. Points carry over text edits: agreed, rationale and cost added under Design.
  5. Separate Semantics/tooltip test: agreed it is extra; folded into the single widget assertion.
- Unverified: no builds, tests or devices run. Not opened by the editor: `memory_editor.dart:56-59` (autosave via copyWith, cited by Rex), the landed story 8-10 `memory_list_screen.dart`, and docs/reviews/baseline.md. Line references (`json_file_memory_repository.dart:49-53, 130-141, 193-201`; `memory_list_screen.dart:60, 64`) come from the settlement evidence.
