# Story 21: anniversary notices

Eric: "Every day, notify me if and only if there are anniversaries in the
coming week. Have the notification link directly to the main page filtered
with a date range of [date of the notification] to [now + one week]. Add a
setting to toggle anniversary notifications."

## Behaviour

- On each day D where some active person has an anniversary falling on a
  local day from D to D + 7 days (both included), one notification arrives at
  09:00 local. On other days, none.
- An anniversary is a detail of kind `anniversary` with an `eventDate`. It
  falls on its month and day each year from the `eventDate` year on. 29
  February falls on 28 February in other years.
- Lock-screen text is fixed and names no one: "Anniversaries coming up" /
  "Someone you know has an anniversary this week." Private visibility, its own
  channel ("Anniversary notices").
- Tapping it opens the Filter List over the main list, with one
  **Anniversary** filter set to D … D + 7. The Filter List gains the
  Anniversary kind (a date range, like "Date range", but matching
  anniversaries instead of meeting days). Blocked while the camera or a game
  is on top, as practice reminders are.
- Settings > Reminders gains a switch "Anniversary notices", on by default.
  Turning it on asks for notification permission if needed, like the practice
  switch.

## How

The phone schedules notifications ahead; the app is not running every day.
So each `sync()` (every open and resume, as today) works out the next 60
days that qualify and schedules a one-shot notice for each, replacing the
earlier set. Today's is skipped once 09:00 has passed. If the app is not
opened for 60 days the notices stop until it is.

### Core (`rememberem_core`)

- `AnniversaryFilter(from, to)`: a `FilterCondition`. Blank until both are
  set. Matches a person with an anniversary on a local day in the range.
- `AnniversaryNotice`: `days(people, from, count)` returns the days, among
  `count` from `from`, whose coming week has an anniversary; `wireId(day)` is
  `anniversaries:YYYY-MM-DD`; `dayFromWire(payload)` reads it back (null for
  anything else; payloads are untrusted).
- `ReminderSettings.anniversaries` (bool). A missing key reads as on, so
  existing `reminders.json` files keep loading; a mistyped one reads as off.
  Defaults and `off()` as their names say.

### App

- `ReminderScheduler`:
  - `scheduleAnniversaries(List<LocalDay> days)` replaces every earlier
    notice (ids 100–159; an empty list cancels).
  - `taps` and `launchGame()` become `taps` / `launchPayload()` carrying the
    raw payload string. The app decodes it with `PracticeGame.fromWireId`
    or `AnniversaryNotice.dayFromWire`.
- `ReminderCoordinator`:
  - `_sync` handles the two switches separately. A missing permission turns
    both off, as now for practice.
  - `setAnniversaries(bool)` turns notices on (asking permission) or off.
  - `askOnce` saves both answers.
  - A `clock` is injected for tests.
- `RememberemApp._openReminder` opens a game or the Filter List with the
  Anniversary filter (route `AppRoutes.anniversaries`).
- `FilterKind.anniversary` and `FilterRow`: a date-range picker, like Date
  range.
- `RemindersSection`: the new switch.

## Tests

- Core:
  - the `AnniversaryFilter` window, including year wrap (28 Dec – 4 Jan),
    29 Feb, an event in the future, trashed people and non-anniversary
    details;
  - `AnniversaryNotice.days`: exactly the qualifying days;
  - the wire round-trip and rejection of bad payloads;
  - `ReminderSettings` reading old files.
- App:
  - the coordinator schedules the right days, cancels when off or there are
    no anniversaries, and turns off when permission is gone;
  - the switch;
  - a cold and a warm tap opening the Filter List with the filter set;
  - the camera blocking it;
  - the notice text naming no one.

## Plan check amendments (`archie`, `rex`)

- **Window:** 30 days, not 60, which keeps the iOS cap of 64 pending
  notifications in reach.
- **Ids:** notices use ids 100–129, keyed by date (`100 + epochDay % 30`).
  A sync schedules the new set first, then cancels the ids it no longer
  uses, so an interrupted sync leaves a working set.
- **Practice only:** `cancel()` cancels only the practice reminder, and its
  comment says so. "Nothing to practise" never touches notices.
- **Permission:**
  - one ask (`askOnce`) answers both switches;
  - a permission taken away in Settings turns both off;
  - a refusal from one switch turns off only that switch.
- **Old files:** a `reminders.json` without `anniversaries` follows its
  practice switch. Someone who had turned practice off gets no surprise
  notices.
- **Stale taps:** a tap whose range no longer matches anyone leaves the list
  as it is.
- **Fresh anniversaries:** the list re-syncs when you come back to it, so a
  new anniversary is counted without leaving the app.
- **Today:** the coordinator passes today, and the scheduler skips a time
  already past.
- **Time zones:** after a time-zone change, notices fire at the old zone's
  09:00 until the app is next opened or resumed. This is accepted.
- **Release builds:** the walk checks a reboot.
