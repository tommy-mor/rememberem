# TieBreaker ruling: notes Back handler, pop only if its own route is still current

Stalemate:     Story 13 plan, notes Back handler (`app/lib/src/memories/memory_edit_screen.dart:79-85`). Rex (guard) against Marlin (accept). Archie did not argue.

Walt, long view: Add the guard. Both options are two-way doors, but accepting a known wrong-page pop sets a pattern that stories 14 and the games would copy. His version re-checks `ModalRoute.of(context)?.isCurrent` after the await and resets `_leaving` on abort. Moderate-high confidence.

Hazel, outside view: Add the guard. "Await, then unguarded pop" is a notorious class of rare, unreported bugs, and a one-line route check almost never regresses. She prefers capturing the route before the await, and rejects `removeRoute` because the shortcut's `popUntil` may already have removed the route. She asks that the dropped press be recorded as accepted behavior, and that the plan's `_leaving` and `mounted` be confirmed in the working copy.

Ruling:        Plan check (Rex) wins. Add the guard in the same edit as the handler. Specifically:
  1. Before the await, capture `final route = ModalRoute.of(context);` next to the `NavigatorState` (Hazel's form: no `BuildContext` use after the await).
  2. After the flush: `if (!mounted) return;` then, if `route?.isCurrent != true`, set `_leaving = false` and return without popping. Otherwise `navigator.pop()`.
  3. Do not use `removeRoute`.
  4. No new test, as in the compromise. Note the behavior in the plan's Risks section in one line: "If another route (picture screen, merge picker, dialog) lands during the flush, that Back press is dropped; the user presses Back again."
  5. The middle option (guard only if the builder proves the routes are reachable) is rejected. It asks the builder to prove a negative about an unmeasured flush time.

Why:
  - Marlin's premise is wrong. `mounted` covers the shortcut's `popUntil` but not routes this screen pushes itself (picture screen, merge picker). Without a check, `navigator.pop()` at :84 removes whatever is on top.
  - The plan's `_leaving` is never reset, so a wrong pop leaves the user on the notes page with Back dead. That is a Back trap, in the story whose whole job is to remove them.
  - The cost is one line in one file. The risk is a lost-trust moment for the person using Back, not data loss.
  - Resetting `_leaving` on this intentional abort does not reopen double-pop. The plan's "do not reset after a failure" rule still stands for a throwing flush; an abort is a different case. The flush itself has already completed, so nothing is lost.
  - Working-copy note: the lines read at :77-85 do not yet contain `_leaving`. Those come from the plan, and are not landed. The builder must confirm both `_leaving` and `mounted` exist when making the edit, not assume them.

Strongest point of the losing side, and how the ruling respects it: Marlin is right that the window is probably milliseconds and that a new test is not worth it. The ruling takes both points: no test, no extra abstraction, and the guard is a single check in the existing handler. His "adds a branch" concern is real for a large guard, but not at this size.

Reversibility: two-way door. One handler in one file, no stored data or format. The guard can be removed with one edit.

Reopen if: the builder finds `Navigator.pop` or the AppBar back arrow is blocked while `_leaving` is true (the reset then fails to free the user). Also reopen if a measured flush time or a test shows the guard drops a legitimate single Back press, or if a later story needs the notes screen to pop itself when it is not current.

Not checked: flush duration, whether the picture and merge routes are openable during a flush, and whether the AppBar leading arrow goes through the same handler. All unmeasured, and nothing was run.

A ruling is a recommendation; Eric can overrule it at any time.
