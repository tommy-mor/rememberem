# Story 12: Remembered metric

## Goal
Fred sees a small, encouraging line on the main list: how many faces and details he remembers. Anything with 5 or more points counts. The number is derived and read-only.

## Acceptance criteria
1. The list shows "Remembered: 12 faces · 30 details" in small, calm text near the practice controls, once the list has loaded.
2. A face counts when the active person's own `points` is 5 or more (inclusive). 4 does not count.
3. A detail counts when its own `points` is 5 or more, its text is non-blank, and its owner is active. The owner's face score is irrelevant.
4. Trashed people and their details never count. Restoring brings them back.
5. Trashing a person drops the count at once, without leaving the screen. Undo restores it.
6. After a game closes, the list shows the new counts (a wrong tap that resets a 5-point item lowers them).
7. Nothing is shown while the list is loading or failed. With no people the line is absent. With people but zero remembered, the line reads "Remembered: nothing yet, practice to start" (invitation, no "0 faces").
8. Wording is never shaming: no percentage, no "of N", no "forgot", no red.
9. Opening or displaying the list calls `all()` once per load and writes nothing. Trash and Undo reload as they do today.
10. The line is visible alongside the practice controls and the FAB (one smoke assertion), and is checked visually once on a device.

## Design
Data: no changes. No new JSON keys, so records on disk are untouched. Depends on landed `Memory.points` (story 10) and `Detail.points` (story 11); `Memory.points` and `Detail.points` are not in the tree at 630a187; they come from plans 10/11, so the names are assumed. First build step: grep the landed code and compile-check both field reads. If story 11 did not make points per detail (for example a per-person counter), stop and ask before building.

Core (one class per file, exported from `packages/rememberem_core/lib/rememberem_core.dart`):
- `lib/src/remembered_count.dart`: `class RememberedCount { final int faces; final int details; const RememberedCount(this.faces, this.details); static const int threshold = 5; factory RememberedCount.of(List<Memory> active) }`. `of` assumes the input is the active list (as `all()` returns) and does not mutate it. Faces: `m.points >= threshold`. Details: sum over people of `detail.points >= threshold && detail.text.trim().isNotEmpty`. Define `==`/`hashCode` for tests. The blank-text rule is written inline as `detail.text.trim().isNotEmpty` (story 11's `eligible` needs Random and clock and exposes no bare predicate); do not touch story 11 files. No options parameter.

Ruling on ambiguity: the story text says "anything with 5 or more points counts", and each Detail has its own points, so details are counted by the detail's own points, not the owner's. The earlier note ("details of people with points >= 5") is superseded, since it would ignore the details game entirely.

App:
- `app/lib/src/memories/memory_list_screen.dart`: in `build`, when `_memories != null` and non-empty, compute `RememberedCount.of(_memories!)` (not cached in `_reload`, because `_trash` edits `_memories` optimistically). Render via a new small widget.
- `app/lib/src/memories/remembered_label.dart`: `RememberedLabel(RememberedCount count)` renders a `Text` with `bodySmall`, muted onSurface color, centered, with no `Semantics` wrapper (Text is already read by screen readers). Faces and details use "1 face" / "1 detail" singular. Zero both: the invitation text.
- Placement: a line directly above story 10/11's practice-control row, inside the same bottom `SafeArea` column, so it moves with the controls and clear of the extended FAB Not a new overlay. Build step: grep `memory_list_screen.dart` for the landed control row and state the chosen placement in the commit. Default if stories 10/11 landed without a bottom column: a `Column` above the `ListView` in `_body`, or `bottomNavigationBar`. The label shows only when `_memories` is non-empty, wherever it sits.

## Tests
- Core `remembered_count_test.dart`: people at points 4, 5, 6 give faces 2 (boundary). Details at 4 and 5: exactly the 5 counted. A blank/whitespace detail at 5 is excluded. A detail at 5 under a person at 0 counts; a detail at 0 under a person at 5 does not. Empty list gives (0, 0). Input list unchanged. `of` trusts its input, so the trashed-person case is covered at list level below, not in core.
- Widget `remembered_label_test.dart`: "Remembered: 1 face · 1 detail" singular; "2 faces · 0 details"; zero shows the invitation and never the string "0 faces".
- Widget list (`memory_list_screen_test.dart` additions, fake repo): known scores show the exact text; absent while loading (completer held) and with an empty repo; trashing a remembered person drops the face count immediately, Undo restores it; pushing a route, changing fake scores 4 to 5, then popping updates the text (didPopNext); after open plus a rebuild the fake's `all()` count is unchanged and it records zero writes.
- Widget layout: one smoke assertion that the label is found alongside the controls and the FAB. Visual device check once.
- Integration: none new; the existing smoke launch covers it.

## Risks and mitigations
- Field names from stories 10/11 not yet verified: the count takes `List<Memory>`, so only two field reads touch them; compile errors point straight at them.
- Drift in the "non-blank" rule: inline trim rule; one test pins it.
- Stale count after trash: computed in `build`, tested.
- Bottom crowding: the label shares the control column (or the defined fallback); smoke assertion plus one device check.
- Demotivating display at low numbers: invitation wording at zero, no denominator, no percentage.
- Wrong-tap resets make the number fall: accepted, it is the truthful measure; copy stays neutral.
- Inherits baseline risk 20 (stale list refresh): the metric derives from `_memories` in `build` and adds no refresh path of its own, so it is exactly as fresh as the `didPopNext` reload. Read-only build step: confirm the landed story 10/11 game screens await `recordAnswer`/`recordDetailAnswer` before the `Navigator.pop` that returns to the list. If they do not, raise it against those stories rather than patching here, or record it as an inherited risk in the commit. This story's `didPopNext` test uses the instant-save fake and adds no delayed-save fake.

## Out of scope
A denominator or percentage, history or trend, per-person points on cards, tapping the metric to see which items count, persistence or caching, settings for the threshold, back navigation (13), reminders (14).

## Baseline record changes
Add "Story 12: remembered metric". The list shows `RememberedCount` (faces with `points >= 5`, non-blank details of active people with `points >= 5`), derived in `build` from the loaded active list and read-only. Add `RememberedCount` and `RememberedLabel` to the Map. Add an invariant: the metric never writes and makes no extra `all()` call. Record the ruling that details count by their own points (gated on story 11's per-detail field). Update the tests line.

## Review record
- Crews and agents: the plan was reviewed by Tess, Archie and Gill; Vera settled the disputes; the neutral plan editor applied the settlement. No TieBreaker was needed.
- Objection 1 (Tess): the plan ignored known risk 20, so the `didPopNext` refresh could read stale data if a game's save is unawaited, and an instant-save fake cannot catch that. Counter (Archie, Gill): risk 20 concerns the edit screen's dispose flush, not the game screens, which are not in the tree at 630a187. Settled by Vera as agreed. Applied: a Risks line saying the metric inherits risk 20, and a read-only build step to confirm the game screens await the record call before popping. No delayed-save fake is added, and the existing test is unchanged. Evidence: baseline.md line 79, memory_list_screen.dart:43-46, :61, :63-66.
- Stalemates: none.
- Rulings: none (docs/reviews/rulings/ precedent consulted only as named in the task; no new ruling file).
- Unverified: `Memory.points` and `Detail.points` names and semantics (stories 10/11 are not landed here); whether the game screens await their saves; the landed layout of the practice-control row; the on-device look. This editor did not re-read baseline.md and relied on the settlement's citations of it.
