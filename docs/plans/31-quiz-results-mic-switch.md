# Story 31: the Show countdown runs, quiz results, a mic that hands over

## What Eric asked

1. "The Show Places and show people buttons should automatically click
   after 3 seconds. The background should animate like a progress bar."
   On his phone he "saw no progressive fill and it never pressed itself".
2. "If I click a different microphone while another one is recording, it
   just keeps recording on the original field. Instead it should stop the
   recording and transcribe what it got, then start recording for the new
   field."
3. "After a quiz, show me my results. Give me a little emotional reward for
   crossing the memory threshold on anything."
4. A label above the quiz buttons: "Quizzes to help you remember..."
5. The default right-answer threshold is 10, not 5.

## Findings

- **Why the countdown never ran.** Both games pass
  `running: !_paced && !_hidden`, where `_paced` is
  `MediaQuery.accessibleNavigationOf(context)`. On Android, Flutter's
  `AccessibilityBridge.createAccessibilityNodeInfo` sets accessible
  navigation to true the first time *any* accessibility service reads the
  screen. That includes password managers, wearable apps and Samsung's own
  services, not just TalkBack. So on Eric's Galaxy the button stood empty,
  waiting for a tap. His settings.json has `revealSeconds: 3` and no
  `revealDelay` (which reads true), so the settings were not the cause.
- **Why the mic stays on the first field.** `DeviceDictation.listen`
  calls `_finish()` (the first field's onDone) and then `_speech.listen`
  while the recogniser is still running. The plugin's native listen does
  not restart a running session. The first session keeps going and its
  words still reach the first field's closure.

## Design

### Countdown

- Drop `_paced` from both games. The countdown always runs (except while
  hidden). Screen-reader users who want time can turn the delay off
  (Settings, story 26), which shows the choices at once. The semantics hint
  "Shows by itself after 3 seconds" stays.
- `CountdownButton` draws a clear progress bar: the fill is solid
  `scheme.primaryContainer` growing from the left over the
  `secondaryContainer` track, with the label on top in
  `onPrimaryContainer`/`onSecondaryContainer`, readable over both. The
  4 px primary bar along the bottom edge stays.
- Tests: the existing countdown widget tests, plus a game test with
  `accessibleNavigation: true` in MediaQuery in which the button still
  presses itself.

### Mic hand-over

- `Dictation.stop()` resolves only once the session's last words have been
  passed on and `onDone` has run (at most `DeviceDictation.stopWait`,
  1.5 s, then it gives up waiting).
- `CuedDictation.listen` stops a session still running (awaiting `stop()`,
  which dings the stop and delivers the final words to the first field)
  before the start ding of the new one. Only then does the new session
  begin, so no words cross fields.
- `DeviceDictation.stop()` calls `_speech.stop()`, then waits for the
  plugin's done/notListening status (which runs `_finish`), with the 1.5 s
  limit. `listen()` calls `stop()` first if a session is live, instead of
  `_finish()`.
- Tests (with a fake inner Dictation): a second listen while the first is
  live calls stop on the inner one first; the first field's onDone runs
  before the second's listen starts; words of the first session after the
  hand-over go to the first field only. A field test: tapping mic B while
  A listens ends A (its icon back to a mic) and starts B.

### Results

- Each game keeps a list of `QuizResult`s, one per turn:
  - what was asked (the person, or the person and the detail);
  - whether it was right first try;
  - the points before and after.

  It is computed from the recorded answer: right first try means
  before + 1, otherwise 0. A failed record keeps the points before.
- `QuizResult` is in core (pure Dart), with `crossed(threshold)`: before <
  threshold ≤ after.
- `QuizResultsView`, a new widget, replaces the "Done: 7 of 10" message:
  - the score at the top ("7 of 10 right first try");
  - then one row per turn: the photo, the name (and for details, the
    detail's short text), a ✓ or ✗, and the progress pie (`ProgressBadge`)
    after the answer;
  - "Practice again" and "Done" buttons.
- **The reward.** If anything crossed the threshold this game, the results
  start with a celebration banner: "You remember Ann now!" (or "You
  remember 3 new things!"). It has a gentle burst of gold sparkles (a
  one-shot `CustomPainter` animation of about 1.2 s, skipped when
  `MediaQuery.disableAnimations`). The rows that crossed show the shiny
  green pie and a star. The `right` chime plays once more as it appears
  (respecting mute). There are no streaks, no nagging and no "come back
  tomorrow".
- Games get `threshold` (from `settings.rememberedThreshold`) through
  `PracticeScreens`.

### Label and threshold

- Above the Faces/Details buttons: "Quizzes to help you remember..." in
  `titleSmall`.
- `RememberedCount.defaultThreshold` becomes 10, and
  `rememberedThresholdRange` becomes 3–20 (so 10 is not the top). A stored
  value is kept. Eric's phone has 5 stored, so it stays 5 until he changes
  it in Settings (said in the hand-over).

## Tests

- Core: `QuizResult.crossed`; the default threshold and range; an older
  settings.json keeps its threshold.
- App:
  - the countdown with accessible navigation;
  - results after a face game and a detail game (rows, score);
  - the banner only when crossed, and none when nothing crossed;
  - the label;
  - the dictation hand-over (above).

## Amendments after Plan check (archie, marlin, gill)

- **Accessible navigation.** This is verified in the installed engine:
  `AccessibilityBridge.java:804` calls `setAccessibleNavigation(true)`
  inside `createAccessibilityNodeInfo`, which runs whenever any service
  reads the view tree.
- **Hand-over mechanics:**
  - `CuedDictation` keeps `int? _live` (the session from its listen until
    its `end`). `listen` calls `stop()` when it is set, before
    `++_session`.
  - `DeviceDictation` keeps a `Completer` made in `listen`, completed in
    `_finish` (idempotent; `_finish` also runs from onError and onStatus).
    `stop()` awaits it for up to `stopWait`.
- **Threshold.** The games read `widget.settings?.value.rememberedThreshold`
  (falling back to the default in tests). There is no new parameter. The
  points after an answer are derived (before + 1, or 0), since
  `recordAnswer` returns void. The person or detail is loaded fresh each
  turn.
- **The reward is smaller** (marlin): no sparkle painter.
  - A crossing gives a banner at the top of the results: a star icon and
    "You remember Ann now!" (several: "You remember 3 more now!").
  - The crossed rows get the shiny green pie and a star, and the right
    chime plays once.
  - `QuizResult` lives in `app/lib/src/practice/`. It has one consumer.
- **A miss is shown kindly** (gill): a ✗ row shows the right answer and
  "You'll see them again soon", not an emptied pie.
- **Not adopted:** gill's one-point-a-day rule. It changes scoring, so it
  is noted for Eric and is not in this story.

## As built (after Baseline: tess, rex, sally; supersedes the above)

- **Countdown:** `_paced` is gone from both games. The fill is solid
  `primaryContainer`. A game test with `accessibleNavigation: true` proves
  the button still presses itself.
- **Mic hand-over**, hardened after tess and rex:
  - `CuedDictation` claims its session number before waiting, so the last
    of quick taps wins. It stops the recogniser only when a session is
    really listening (`_live`), so a replace during the start ding still
    ends silently.
  - `DeviceDictation`:
    - runs starts one at a time (`_starting`), so a second tap during the
      first's permission prompt finds it running and ends it;
    - ends a session on "done" only. The plugin sends "notListening"
      before the final words, so "notListening" only starts a 1.5 s
      fallback;
    - `stop()` waits up to `stopWait` and cancels the recogniser if no
      "done" comes;
    - results are tagged by session, so a late one is dropped, never
      misrouted.
  - `DictatedTextField` ignores words once it has stopped listening.
  - Tests use a fake `Dictation`. `DeviceDictation` itself is untested
    against the plugin (accepted; it needs a device walk).
- **Results:** `QuizResult` and `QuizResultsView` (in `practice/`). There
  is no "Practice again" button, only "Back to list" as before.
  - The score counts a right first try even if its save failed; a failed
    save adds no points.
  - A crossing gives a green banner with a star, "You remember Ann now!",
    a star on the row, and one chime.
  - A miss shows "You'll see them again soon." and a ✗, no pie.
- **Threshold:** default 10, range 3–20. Tests that relied on 5 now set
  it.
