# Plan 13: Back navigation through every page

## Goal

Fred can press the device Back action on any page and land on the page he came from. This is mostly a verification story: one navigation test walks every real route, and we fix only what it exposes. The likely fix is a once-only, route-checked guard on the notes screen's async Back handler, plus a catching dispose flush.

## Acceptance criteria

1. From the list, open a card, then its picture screen. Back twice returns to the card, then the list.
2. List -> Matching -> card: Back twice returns to Matching, then the list.
3. List -> Timeline -> day -> card: Back three times returns to the day, Timeline, then the list.
4. Places, Trash, the merge picker, and each practice game (face, details) return to the page that opened them with one Back. A game leaves with a plain pop and no confirmation.
5. List -> FAB -> capture -> shutter -> notes: Back returns to the list, not the camera. After Back the list shows and the stack holds one route, with the camera gone.
6. Back on the notes screen saves what was typed first, and the list then shows it.
7. Two quick Backs on the notes screen pop exactly one route. The list stays on screen and the navigator is never empty.
8. If saving fails, Back on the card still returns to the list. It does not hang, and no uncaught error escapes.
9. An open dialog, picker or bottom sheet closes on the first Back, and the page underneath stays.
10. The "Meet someone" shortcut, triggered from the card or a game, leaves the stack as [list, capture]. A second trigger is ignored. Back from the camera returns to the list.
11. Every Back to the list shows fresh data (the didPopNext reload still fires).

## Design

No data model or JSON changes. No new classes. No shared router: story 14 only needs push order, and the shortcut's `popUntil(isFirst)` then `push` pattern is the precedent.

Audit first, at the start of the build: run `grep -rE "PopScope|popUntil|pushReplacement" app/lib` once after stories 9-12 land. Known today: `PopScope` only in memory_edit_screen.dart; `popUntil(isFirst)` in rememberem_app.dart (shortcut) and memory_edit_screen.dart:240 (merge, which flushes first at :226, so it is safe). If `app/lib/src/practice` still lacks the game screens, drop the game rows from criteria 4 and 10 and say so; do not write tests against screens that do not exist. Fix only the double-pop and trap shapes the tests prove.

Expected fix in `app/lib/src/memories/memory_edit_screen.dart` (the PopScope handler, around lines 77-86). The builder must confirm that `_leaving` and `mounted` are what the edit uses; `_leaving` does not exist in the working copy yet.
- Add a `bool _leaving` field. In `onPopInvokedWithResult`, return if `didPop` or `_leaving`. Set `_leaving = true`, then clear snackbars.
- Before the await, capture both `final navigator = Navigator.of(context);` and `final route = ModalRoute.of(context);` so no `BuildContext` is used after the await.
- Wrap the flush in `try { await _editor.flush(); } catch (_) {}` so a throwing repository cannot trap Back. Do not reset `_leaving` after a flush failure (that would reopen the double-pop window). Decision for criterion 8: Back pops anyway. `flush()` rethrows after setting the editor dirty (memory_editor.dart:175-182), so the edit stays marked dirty, but the dispose flush is the only later attempt and it is a best effort: if the repository stays broken the edit may be lost. Record this in the baseline. (The alternative, staying on the page with a snackbar, is not chosen.)
- After the await, `if (!mounted) return;`. Then, if `route?.isCurrent != true`, set `_leaving = false` and return without popping (TieBreaker ruling, see Review record). Otherwise `navigator.pop()`. No `canPop()` check and no `removeRoute`. This reset is on a deliberate abort after a completed flush, so it does not reopen the double-pop window; the "do not reset after a failure" rule above still applies to a flush that throws.
- Dispose flush: at memory_edit_screen.dart:70 replace the bare `_editor.flush();` with `unawaited(_editor.flush().catchError((_) {}));`, and make the same fix at encounter_edit_screen.dart:43. No new public method. The bare call is not a safe retry: it is unawaited with no catch, so a throwing repository raises an unhandled async error. Note `flush()` returns `_lastSave` even when the editor is not dirty (memory_editor.dart:184), so a bare call can also surface an earlier failure. Only `_flushNow` (:155) catches internally.
- Shortcut flag: `_meetSomeone` awaits `push(capture)`, and `pushReplacement` keeps that future pending until the notes page pops, so `_capturing` stays true while Fred is on the freshly captured notes page and a shortcut fired there is silently ignored. Test it; if confirmed, reset the flag once the replacement happens (smallest change), otherwise record as intended.
- A route already removed by the shortcut's `popUntil` is covered by the `mounted` check. A route pushed above notes by the notes screen itself (picture screen, merge picker, dialog) is covered by the `isCurrent` check.

Capture stays `pushReplacement` (capture_screen.dart:79). This is intended: the camera is transient. Document it in the baseline.

Manifest: unchanged. `targetSdk` is `flutter.targetSdkVersion` (android/app/build.gradle.kts:23) and the manifest has no `android:enableOnBackInvokedCallback`. `PopScope(canPop:false)` is expected to handle both legacy and predictive back; this is from reading the code and is not verified on a device. Opting in is one attribute on the `application` element, a separate decision. The builder looks up the resolved target SDK once and writes the number in the baseline, or writes "not verified". Device-lane check for Fred: type in the card, press Back, confirm the list shows the text.

## Tests

New file `app/test/back_navigation_test.dart`. It boots `RememberemApp` with the fake repository and the fake location, dictation and camera services.
- Route walk: one helper (open X, `tester.pageBack()`, expect X gone and the previous page shown) used for each chain in criteria 1-4, plus a merge assertion: after merging from the card, the stack is [list] and the snackbar shows.
- Capture chain: reuse the Placeholder-then-`pushReplacement` fixture from memory_list_screen_test.dart:95-120, extracted into a shared test helper that story 14 can import. No new fake capture page. The fixture never calls `capture()` (capture_screen.dart:73), so it proves the stack shape only. After one Back, assert the list shows and the stack holds one route. Record creation stays with the invariant 1 core tests.
- Double Back: type text, call `handlePopRoute()` twice without pumping between. Assert the list is shown, `navigator.canPop()` is false, the text was saved, and the list shows the new name (this folds in the reload check, criterion 11).
- Failing save: a repository fake whose `save` throws. After Back, assert the list is shown (the page pops anyway) and that the test fails on any uncaught error (no error reported through the Flutter error handler or the zone, including from the dispose flush).
- Dialog first: open a dialog or picker, press Back, and assert the dialog is closed and the page remains.
- Shortcut: from the card, the freshly captured notes page, and (if the game screens exist) a game, trigger the shortcut. Assert the stack is [list, capture] and Back lands on the list. A second trigger leaves one capture page. Keep this fixture reusable for story 14.
- No test for the `isCurrent` guard or for a shortcut during a flush (per the ruling).

## Risks and mitigations

- Predictive back is off, so Flutter tests cannot prove device behaviour. Mitigation: a manual device check by Fred, listed under Out of scope.
- `popUntil` bypasses PopScope (baseline risk 20). Saving then depends on the dispose flush, now catching. Mitigation: the shortcut test asserts the text was saved.
- Stories 9-12 are not yet in the tree and may add `PopScope` or `popUntil`. Mitigation: the grep audit above, run first; blocked tests are dropped, not faked.
- The camera and ML Kit cannot run in widget tests. Mitigation: use the Placeholder fixture.
- Baseline risk 13 is carried over unchanged and accepted for this story. Back on the camera during "Framing the photo" can leave an unnamed record: capture saves at capture_screen.dart:73 and then returns silently at :78 if unmounted. No capture-in-flight fake is built. The shortcut's `popUntil` can hit the same window.
- If another route (picture screen, merge picker, dialog) lands during the notes flush, that Back press is dropped and the user presses Back again. Accepted. The window is the length of one flush, which was not measured.
- Dropping a Back press resets `_leaving`. Whether the AppBar arrow goes through the same handler was not checked; reopen if Back stays dead while `_leaving` is true.

## Out of scope

- Enabling predictive back in the manifest (a separate decision plus a device check).
- A confirmation prompt on leaving a game.
- A shared router, or the story 14 notification routing.
- Making the dispose flush awaited.
- Baseline risk 13 (Back on the camera mid-capture), knowingly not addressed here.

## Baseline record changes

- Add "Story 13: back navigation". Back rules: every page pops one route per Back; the camera is skipped after capture; the notes Back handler is once-only, route-checked, and cannot be trapped by a failed save.
- Invariant 8: add that Back from the camera returns to the list. Mark it tested.
- Risk 20: note that `targetSdk` is `flutter.targetSdkVersion` (android/app/build.gradle.kts:23; resolved number recorded by the builder, or "not verified"), `enableOnBackInvokedCallback` is absent, and `PopScope(canPop:false)` handling of legacy and predictive back is from reading and not device-verified. Awaiting Fred's device check.
- Risk 3: rewrite as resolved on both counts (later saves are no longer skipped after a failure; Back is no longer trapped; the dispose flush no longer raises an unhandled error). Note the pop-anyway decision and the dispose-flush-only retry.
- Risk 13: stays open. Knowingly not addressed by story 13.

## Review record

Crews and agents: the plan builders (Archie, Marlin), guardians (Tess, Rex), Vera (settlement), and the TieBreaker panel (Walt long view, Hazel outside view). I edited the plan from their settlement; I ran no builds, tests or devices.

Objections and settlement:
1. Dispose flush unawaited with no catch (Tess): facts favour guardians. Fixed with `unawaited(_editor.flush().catchError((_) {}))` at memory_edit_screen.dart:70 and encounter_edit_screen.dart:43; the failing-save test now fails on uncaught errors; the "safe retry" wording was removed.
2. Criterion 5 "no second record" unprovable with the fixture: agreed, reworded to a stack-only claim.
3. Criterion 7 "Back plus the AppBar arrow": agreed, parenthetical dropped.
4. Baseline risk 13 unmentioned (Rex): agreed, carried over and recorded in Risks, Out of scope and Baseline changes.
5. Manifest and target SDK unstated: agreed, manifest unchanged, SDK statement and device check added.
6. Notes Back handler popping a foreign route (Rex vs Marlin): stalemate, settled by the ruling below.

Rulings:
- [2026-11-01-back-navigation-1](../reviews/rulings/2026-11-01-back-navigation-1.md): Rex wins. Add the `ModalRoute.isCurrent` guard in the same edit; reset `_leaving` on abort; no `removeRoute`; no new test; record the dropped press as accepted.

Unverified:
- Resolved target SDK value.
- Predictive back and legacy back behaviour on a device.
- Flush duration, and whether the picture or merge routes can open during a flush.
- Whether the AppBar leading arrow goes through the same PopScope handler.
- Whether `_leaving` and `mounted` exist in the working copy at build time (`_leaving` does not today).
- Whether stories 9-12 added `PopScope`, `popUntil`, or the game screens.
