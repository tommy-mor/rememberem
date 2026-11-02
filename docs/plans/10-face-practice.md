# Story 10: Face practice game

## Goal
Fred can start a ten-turn practice game from the bottom of the main list. Each turn shows a person's face for 3 s with no name, then 4 name choices. He taps until he finds the right one. First-try-correct earns the card a point and a lastCorrectDate; any wrong tap resets its points to zero. Later games prefer weak or stale people.

## Acceptance criteria
1. The main list has a "Practice faces" control at the bottom. It is enabled only when the active people with non-blank names include at least 4 distinct trimmed names; otherwise it is disabled and a line says "Name at least 4 different people to practice."
2. A game has exactly 10 turns, then shows a gentle finish screen ("Done, N of 10 right first try") with a Back to list button. No streaks or shaming text.
3. Each turn shows the face for 3 s. The person's name appears nowhere on screen during that time.
4. After 3 s, 4 buttons show distinct trimmed names: the correct one plus 3 decoys, shuffled. Decoys never repeat the correct name. If two people share a name, that name appears as one button, and a tap on it counts as correct.
5. A wrong tap greys that choice out; Fred keeps picking until correct, then the next turn starts.
6. Correct on the first tap: points +1 and lastCorrectDate = now (UTC), saved.
7. Any wrong tap in the turn: points become 0 immediately (saved even if Fred quits mid-turn). lastCorrectDate is untouched. A later correct tap in that turn earns nothing.
8. Later games prefer low points and long-ago or never-correct people. The same person is never picked in consecutive turns when 2 or more are eligible.
9. Leaving the game or a person vanishing mid-game never crashes or writes to a purged record. When the app goes inactive (notification shade, permission dialog), the face is hidden behind a neutral placeholder and the reveal timer is cancelled, but the game continues and the turn is not scored. On resume the full 3 s reveal restarts for the same person. When the app is paused or hidden, the game ends.
10. Existing records load with points 0 and lastCorrectDate null. Opening the app or the game never rewrites them. Only `recordAnswer` writes during play, and only `points` and `lastCorrectDate`. Editing, trashing, restoring or merging a person keeps points. A late editor save never reverts points.

## Design
Data (`packages/rememberem_core/lib/src/memory.dart`): add `int points` (default 0) and `DateTime? lastCorrectDate` (UTC). `fromJson` reads `points` (default 0) and `lastCorrectDate` (default null). `toJson` emits each only when non-default, so old files stay byte-identical. Carry both through the constructor, `captured()`, `withTrashedAt`, `_copy` and `merged`. Add one helper `Memory.withScore(points, lastCorrectDate)` used by `save()` and `recordAnswer`, so no other site hand-rolls a `Memory(...)` call. Merge rule: the survivor keeps its own values, and the discarded person's are dropped. This is idempotent, so merging the same pair twice changes nothing.

Repository (`memory_repository.dart`, `json_file_memory_repository.dart`, `app/test/fakes/fake_memory_repository.dart`):
- `Future<void> recordAnswer(String id, {required bool correctFirstTry, required DateTime at})`. Implemented via `_update` inside `_serial`. First-try-correct: points+1 and lastCorrectDate=at. Otherwise points=0 and the date is untouched. `_update` throws StateError only when the record file is missing (purged), so the callback also explicitly throws StateError if `onDisk.trashedAt != null`.
- `save()` keeps `points` and `lastCorrectDate` from disk via `withScore(onDisk.points, onDisk.lastCorrectDate)`, as it does `trashedAt`. The fake mirrors both rules.
- The game calls only `recordAnswer`, never `save`. Doc comments state the merge rule.
- Note: `all()` is a plain async method with no `_serial` wrapper (json_file_memory_repository.dart:157), so a read can overlap a queued write. The screen therefore awaits `recordAnswer` before re-reading (see App).

Pure core (no Flutter):
- `face_quiz_planner.dart` `FaceQuizPlanner(Random, DateTime Function() clock)`.
  - `eligible(List<Memory>)` returns every active person with a non-blank name. No name de-duplication: people sharing a name stay quizzable.
  - `distinctNameCount(List<Memory>)` (or equivalent) returns the number of distinct trimmed names among the eligible people. It is the single definition used to enable the control and to end a game whose pool has fallen below 4.
  - `pickNext(eligible, {String? previousId})` makes a weighted draw. weight = 1/(1+points) + min(daysSince, 60)/30. A null lastCorrectDate counts as 60 days. The weight is always positive and finite. It excludes previousId when 2 or more are eligible.
  - `choicesFor(person, eligible)` returns the correct trimmed name plus 3 decoys, de-duplicated by trimmed name (including against the correct name), shuffled. A tap on the shared name counts as correct.
The screen keeps choices and a wrongTapped flag as private state; no separate turn type until story 11 needs one.

App:
- `app/lib/src/practice/face_game_screen.dart`. Stateful, with injected repository, planner and `Duration reveal = 3s`; constructor params default from AppServices so story 14 can open it from a route with only services. The AppBar has a close button. Phases are reveal, choose, finished.
  - Each turn re-reads `repo.all()` in a try/catch; a read error or a pool below 4 distinct names ends the game with a message (no Retry UI).
  - recordAnswer is called at most once per turn: on the first wrong tap (reset) or on a clean first-try correct tap. Further wrong taps do not write.
  - The tap handler awaits `recordAnswer` (success or failure) before advancing and re-reading `all()`. Taps are ignored while the write is pending. After a wrong tap, the write is issued before any further tap is handled.
  - Any exception from `recordAnswer` (StateError for a purged or trashed person, IOException, anything else) is caught, the turn still advances, and the failure is never shown as a point earned.
  - Every continuation after an await (`all()`, `recordAnswer`) checks `mounted` and `_ended` before touching a Timer or setState.
  - A single `Timer` is cancelled in dispose and whenever the app goes inactive.
  - A `WidgetsBindingObserver` handles lifecycle. On `inactive`: show a neutral placeholder instead of the face, cancel the reveal timer, do not end the game or score the turn. On `resumed`: restart the full 3 s reveal for the same person. On `paused` or `hidden`: set `_ended` and end the game. The face stays out of the app switcher (baseline risk 16).
  - The face is shown with `repo.photoFile`, and `errorBuilder` shows a neutral placeholder.
- `app/lib/src/memories/memory_list_screen.dart` gets a bottom `SafeArea` control. It decides enablement with the planner's `distinctNameCount` over `eligible(_memories)` being >= 4 (one definition of quizzable), avoids overlapping the existing `floatingActionButton.extended` (line ~157) via bottom list padding or a `bottomNavigationBar` placement, pushes the game, and reloads on `didPopNext`.

## Tests
Core:
- Compat: a story-7 JSON loads with 0/null, and toJson for a default record has no new keys. A record with points 3 and a UTC date round-trips equal.
- Copy paths: withTrashedAt, withField, withEncounters and merged keep points. Merging the same pair twice is a no-op, and the survivor's points win.
- Repository: `recordAnswer`, then `save()` of a stale Memory with a new name, leaves points and date on disk and the name changed. The reverse order keeps both too. `recordAnswer` on a trashed or purged id throws StateError.
- Planner: the pure weight function is asserted directly (weight(0 pts, never) > weight(5 pts, today), always positive and finite), plus one seeded draw (no large statistical loop). With 2 eligible, previousId is never repeated. A single eligible person is returned without error. Blank names are excluded from eligible. Two people named Sarah: both are pickable as subjects, Sarah appears as one button in choicesFor, and decoys never repeat the correct name. distinctNameCount counts Sarah once. choicesFor gives 4 distinct names including the correct one.

App widget tests (fakeAsync, fake repo, seeded Random):
- Name text is absent at 2.9 s and 4 buttons appear at 3.0 s.
- Wrong then right leaves points at 0 and the date unchanged. Starting from 4 points, a wrong tap makes it 0 immediately.
- First-try-right gives points+1 and date=clock.
- The game ends after exactly 10 turns and shows the finish text.
- Disposing mid-reveal leaves no pending timers and no writes.
- A person purged mid-game is skipped without an exception.
- Two wrong taps in one turn cause exactly one write.
- Fake repo whose `recordAnswer` completes late: after a first-try-correct, the next pick sees points+1; taps are ignored while the write is pending; after a wrong tap the write is issued before any further tap is handled.
- Fake repo whose `recordAnswer` throws IOException: the game reaches the finish screen with no uncaught exception, and no point is shown as earned.
- Hold `all()` or `recordAnswer` on a Completer, dispose, then complete it: no exception, no pending timer, no further write.
- Lifecycle: the face widget is absent while inactive; resume restarts a full 3 s reveal with no write; paused ends the game.
- On a small screen the practice control does not overlap the FAB.
- The list control is disabled with the message when there are fewer than 4 distinct names (including 4 people with only 3 distinct names), and enabled with 4 distinct names.

Integration: the existing app run is enough. Smoke-test by launching the app with 4 people and playing one turn.

## Risks and mitigations
- Stale-write clobber (baseline risk 20): handled by `recordAnswer` plus `save()` preserving the score fields. Both are tested in either order.
- Unserialized `all()` read overlapping a queued write: the screen awaits `recordAnswer` before the next read.
- One corrupt record breaks `all()` (risk 2): the game catches the error and ends with a message instead of spinning.
- Missing photo file: placeholder, and the turn still works.
- Punishing feel: neutral copy, and points are not shown on the card. A shortened reveal after resume is avoided; the full 3 s restarts.
- Fewer than 10 eligible people: the game still runs exactly 10 turns; repeats are allowed but never back to back. Running min(10, N) turns would be a one-line change if Eric prefers it.

## Out of scope
Details game (11), the 5+ metric (12), back-navigation work (13), reminders (14), showing points on the card, per-game history, sounds, difficulty settings.

## Baseline record changes
Add "Story 10: face practice". Memory has `points` and `lastCorrectDate`, which are omitted at default and kept by save, trash, restore and merge (the survivor wins). Scores change only through `MemoryRepository.recordAnswer`, serialized, and `save()` preserves them. Add `FaceQuizPlanner` and `FaceGameScreen` to the Map. The list has a practice control that needs 4 distinct named people (same-named people remain quizzable but share one button). Update the absent-from-code list and the tests line. Add that the game hides the face on inactive and ends on paused/hidden, and note the corrupt-file risk 2 is handled in the game only.

## Review record
Crews and agents: a review crew named in the settlement (Tess, Archie, Gill, Rex, Grace) raised objections; Vera produced the settlement; this neutral editor applied it. Their individual transcripts were not available to the editor.

Objections and settlements (all agreed, no stalemates):
1. Screen must await `recordAnswer` before the next `all()` read, since `all()` is not serialized. Applied: awaiting handler, taps ignored while pending, late-completing fake test.
2. Only StateError was caught from `recordAnswer`. Applied: any exception is caught, the turn advances, no false point; IOException test.
3. Continuations after awaits could run after dispose or game end. Applied: `mounted` and `_ended` guards plus a Completer-based dispose test.
4. Criterion 10 contradicted score writes; same-named people were dropped; the 4-choice threshold must count distinct names. Applied: criterion 10 reworded, `eligible()` no longer dedupes, `distinctNameCount` added, `choicesFor` dedupes decoys, criteria 1 and 4, Design and list enablement updated, Sarah test added.
5. Inactive versus paused. Applied: inactive hides the face and cancels the timer without scoring; resume restarts the full 3 s; paused or hidden ends the game; criterion 9 and tests updated.
6. The 2000-draw statistical test: agreed, no change (plan already tests the weight function plus one seeded draw).
7. Fewer than 10 eligible people: agreed, no change; min(10, N) noted as a one-line option.

Rulings: none (no TieBreaker rulings applied; docs/reviews/rulings/ precedent not consulted beyond what the settlement carried).

Unverified: no builds, tests or devices were run. Line references (json_file_memory_repository.dart:157, 208; list screen ~157) come from the settlement and the prior plan and were not re-checked against code. Whether the `bottomNavigationBar` or list-padding placement avoids the FAB is untested.
