# Story 6: Meeting auto-fill

## Goal
When Fred takes a picture at a place the app filled in (story 5) and a known meeting happened there within two hours of now, the new person's Meeting field is already filled when the notes screen opens. If several match, the meeting closest in time wins. Fred's typing is never overwritten.

## Acceptance criteria
1. Capture at a matched place, with an earlier encounter at that same place whose meeting is non-blank and whose capture time is within 2 hours, opens the notes screen with Meeting showing that name.
2. With several qualifying meetings, the one closest in time wins, whatever the order of people on disk (30 min beats 90 min).
3. Exactly 120 minutes counts (inclusive); 121 minutes does not.
4. Time difference is absolute: an encounter dated later than the new capture (after a re-date) within 2 hours counts.
5. No place matched (no GPS fix, no match, blank place) gives a blank meeting, even if a meeting is near in time.
6. Encounters with a blank meeting, a different place, or belonging to a trashed person are ignored even when closest. Every encounter of every active person counts, not just the newest.
7. A meeting Fred types or edits is saved as typed. Auto-fill happens only once, in the capture's single add(), never on load, save, merge, or when Fred edits Place on the notes screen.
8. A capture still creates exactly one person with one encounter and never loses the photo, even if lookup fails. Lookup failure gives a blank place and meeting.

## Design
Derived at capture time from the same single early `repository.all()` read as story 5 (this story depends on story 5's `known` future and `list` variable and must not issue a second `all()`). Story 5 only reads when location is non-null and yields a null list on failure; a null location or null list means no place, so no meeting. No store, no cache. Saved JSON format is unchanged because Encounter already serialises `meeting`.

Core (pure Dart):
- New `packages/rememberem_core/lib/src/meeting_finder.dart`: `const MeetingFinder()` (const constructor, so it can be a default parameter value) with a fixed `static const window = Duration(hours: 2)` and `String suggest(String place, DateTime at, Iterable<Memory> active)`. Returns '' if `place.trim()` is empty. Scans all encounters of `active` where `samePlace(e.place, place)` and `e.meeting.trim()` is non-blank; keeps `at.difference(e.capturedAt).abs() <= window`; picks smallest gap, ties broken by the existing `Encounter.newestFirst` ordering, so disk order never matters. Returns the meeting trimmed, otherwise verbatim. Exact, case-sensitive place match: no fuzzy matching.
- Place key: one public `static bool samePlace(String a, String b)` (trim equality) on `MeetingFinder`; stories 7 and 8 reuse the same identity rule.
- `memory.dart`: `Memory.captured` gains optional `String meeting = ''`, written to the first encounter. `memory_repository.dart`: `add(...)` gains optional named `String meeting = ''` beside `place`. Update `json_file_memory_repository.dart` and `app/test/fakes/fake_memory_repository.dart` together. Encounter already stores `meeting`, so no JSON change.
- `rememberem_core.dart`: export `meeting_finder.dart`.
- `portrait_capture.dart`: add a defaulted optional parameter `this.meetingFinder = const MeetingFinder()` (no call-site edits). Inside story 5's same try/`on Exception` guard, after `await known` and `PlaceFinder.nearest`, compute `place` then `meeting = (list == null || place.isEmpty) ? '' : meetingFinder.suggest(place, capturedAt, list)` and call `add(place: place, meeting: meeting)`. `suggest` sits inside the guard so any failure gives blanks. `capturedAt` is the timestamp the new encounter will store (use one value for both). Times are compared as stored (local ISO strings); a DST change can shift a gap by an hour (accepted).

UI: none. CaptureScreen already hands the returned Memory to the notes screen.

## Tests
Core unit (`packages/rememberem_core/test/meeting_finder_test.dart`):
- Cafe 'Standup' 90 min earlier and 'Lunch' 30 min earlier: 'Lunch' for both list orders.
- 120 min returns the name (inclusive); 121 min returns ''.
- Encounter 30 min later than `at` is chosen; equal-gap tie gives the same name in both orders.
- Closest encounter ignored when meeting blank or place differs; farther qualifying one wins. A non-latest encounter counts. Blank place argument gives ''.

Core capture (real temp dir, `portrait_capture_test.dart`):
- Saved 'Cafe'/'Standup' 20 min ago with location; capture 50 m away: saved `latest.place == 'Cafe'` and `latest.meeting == 'Standup'`.
- Null location with a near-in-time meeting: meeting ''. Repository whose `all()` throws an Exception: one Memory, one encounter, blank place and meeting, photo present, `all()` called once.

Widget (fake repo, `app/test`):
- After capture the notes screen shows 'Standup' in Meeting; a meeting typed instead is saved as typed.

## Risks and mitigations
- Wrong confident fill (another gathering same day, or typo propagating): Fred edits it; no indicator. Accepted.
- Place variants (case, whitespace inside) will not match: exact trimmed match, documented; story 9 place renaming is the cure.
- Lookup failure after raw file deletion (baseline risks 1, 2): story 5's guard now also wraps `suggest`; tested.
- Capture-only: the story says "when a picture is added", so Place edits on the notes screen do not re-run matching.
- Latency: no extra read; the scan is in memory over data already loaded.

## Out of scope
Matching on notes-screen Place edits, fuzzy or case-insensitive place matching, a configurable window, a "filled automatically" indicator, meeting-only matching without a place, filter and timeline grouping (7, 8), meeting renaming.

## Baseline record changes
- Map: capture fills the new encounter's meeting from the closest-in-time meeting (within 2 h) at the auto-filled place, derived from active people's encounters.
- Extend the story 5 auto-fill invariant: place and meeting are filled together in the one add(); best-effort, never overwrites typing, excludes trashed people. Tested: yes.
- Repository `add` and `Memory.captured` take an optional meeting. Core gains `MeetingFinder` (also the shared `samePlace` rule). Invariant 1 unchanged; risks 1 and 2 notes: no new loss path.

## Review record
- Crews and agents: the plan was reviewed upstream of this edit; Vera's settlement came back with no disputes and no stalemates, so no plan_changes were applied. Details of individual reviewer agents were not passed to the plan editor.
- Objections and settlements: none outstanding.
- TieBreaker rulings: none issued (no files in docs/reviews/rulings/ apply to this story).
- Unverified: nothing was built, tested or run during planning. The plan depends on story 5 landing first (`known` future, `list` variable, `PlaceFinder.nearest`, `add(place:)`); the exact shape of story 5's code was not re-checked against the repository.
