# Story 26: quizzes use the filtered list, a Show countdown, mute, chime, pie badges

## What Eric asked

1. The quiz "Show" button's background is a progress bar that runs out and
   presses itself after 3 seconds.
2. A setting turns the show delay off.
3. A mute toggle on each quiz screen.
4. A more pleasant chime, something like a low-then-high woodblock tap, and
   quieter.
5. The badge on each person shows a small pie chart of progress toward the
   "remembered" threshold, not a number. Badges turn green and shiny once
   they reach the threshold.
6. Quizzes pick people only from the filtered list. A quiz started from a
   reminder uses everyone. When a quiz starts while the list is filtered, a
   full-page dialog first:
   - says how the list is filtered;
   - says how many people and details that leaves for this game;
   - offers "Play with the filtered list" or "Play with everyone".

## Design

### Core

- `AppSettings.revealDelay` (bool, default true; a missing key reads true).
  When false, a turn shows its choices at once.

### Show countdown

- `CountdownButton`, a new widget: a FilledButton-shaped control whose
  background fills from left to right over [duration]. An
  AnimationController draws the fill; a Timer presses it, so the press
  comes exactly [duration] after the start. A tap presses it at once. It
  listens for the app going inactive itself, and stops at once.
- During the reveal phase both games always show it ("Show names" or "Show
  people"); before, it showed only with a screen reader. With a screen
  reader on (`_paced`), it does not count down; it waits for a tap, as now.
  The game's own reveal Timer goes, since the button owns the countdown.
  Leaving the app mid-reveal still hides the face and restarts the reveal on
  return (the controller resets).
- With `revealDelay` off, a turn goes straight to the choose phase.

### Mute

- `MuteButton(settings)`, a new widget: an IconButton in both games' AppBar
  actions, before Home. It shows `volume_up` or `volume_off` with the
  tooltip "Mute sounds" or "Unmute sounds". It flips `settings.sounds`, so it
  is the same switch as in Settings and is remembered.

### Chime

- `make_sounds.py` makes `right.wav` as two woodblock taps:
  - about 520 Hz then 780 Hz, 90 ms apart;
  - each a fast-decaying sine with an inharmonic partial (×2.76) and a 3 ms
    noise click;
  - peak around 0.18, half the old volume.

  `wrong.wav` is also lowered, to 0.2.

### Pie badges

- `ProgressBadge(points, threshold)`, a new widget, is a circle (22 dp,
  growing with large text to 40) drawn
  with a CustomPainter:
  - the track is the primary colour at 25%;
  - the arc fills in proportion to `min(face points / threshold, 1)`;
  - at or past the threshold it is solid green with a white highlight
    (shine) and a check, and the tooltip says "Name remembered".

  It shows the person's face points, the measure "remembered" uses for
  faces. A person with no face points shows nothing, as now.

### Filtered quizzes

- `PracticeScreens.build(game, services, {Set<String>? pool})`: the ids of
  the filtered people, fixed when the game starts. Each game keeps only
  those people from `repository.all()` before planning.
  Choices then also come from the pool, so a pool needs 4 names (faces) or 4
  people and a detail (details), as now.
- The list's Faces and Details buttons: with no filter on, play as now. With
  a filter on, push `FilteredPracticeScreen` (a full-screen dialog route).
  It shows:
  - one line per active filter, worded by `FilterKind.describe(condition)`
    ("Place: Cafe", "Date range: 1 Nov 2026 – 3 Nov 2026");
  - "N people, M details for this game" (M is the eligible count: faces for
    Faces, details for Details);
  - "Play with the filtered list", disabled with the reason when the
    filtered pool cannot play;
  - "Play with everyone".

  It replaces itself with the game. A reminder's game is built with no pool,
  as now.
- The practice bar's buttons stay enabled by "everyone can play", since the
  dialog handles a filtered list that cannot.

## Tests

- **Settings:** `revealDelay` round-trip, and missing reads true.
- **Countdown:** the button fills and presses itself after the duration; a
  tap presses it early; with accessibleNavigation it never presses itself.
- **No delay:** the choices show at once.
- **Mute:** it toggles `settings.sounds` and its icon.
- **Badges:** below the threshold, a partial pie; at it, the green
  "Remembered" badge.
- **Filtered quiz:**
  - with a filter, Faces opens the dialog with the filter line and counts;
  - "Play with the filtered list" asks only filtered people;
  - "Play with everyone" uses all;
  - a pool too small disables the filtered button;
  - with no filter, there is no dialog.
- **Reminder:** a quiz started from a reminder ignores the list's filters.
