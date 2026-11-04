# Story 29: anniversary notices name people; debug controls on About

## What Eric asked

- Show the person's name in the anniversary notice, and update the
  Settings description to match. "I don't want the app making me click more
  than I have to."
- When the app is a debug build on his phone, add a debug section to the
  About page. Its buttons fire:
  - an anniversary notice for a date he picks;
  - a quiz reminder;
  - a place notification for a chosen place. This button comes with
    story 30, which is where place notices are built.

## Design

### Named notices

- **Core.** `AnniversaryNotice.title` is "Anniversaries this week".
  `AnniversaryNotice.textFor(active, day)` lists each person with an
  anniversary from `day` to a week later, with the type and the day:
  "Ann Lee – wedding, 5 Nov; Bo – birthday, 8 Nov". Today's reads "today".
  - Order: by date, then by name.
  - At most 4 people, then "and N more".
  - People with no name show as "Unknown".
- **Scheduler.** `ReminderScheduler.scheduleAnniversaries` takes
  `Map<LocalDay, String>`: each day with its text. The "unchanged" cache
  key includes the text, so a rename or a new anniversary reschedules.
  The coordinator builds the map from `AnniversaryNotice.days` and
  `textFor`.
- **Lock screen.** The notice keeps `NotificationVisibility.private`. On
  Android a locked phone shows only "Rememberem: Contents hidden" unless
  Fred allows private content in his own settings. iOS hides previews when
  locked by default.
- **Wording.** The places that promise "never names anyone" change:
  - the Settings switch: "A morning note naming who has an anniversary
    in the coming week. A locked phone hides the names.";
  - the privacy policy;
  - CLAUDE.md.

  The practice reminder still names no one.

### Debug controls

- `DebugSection` is a new widget. It shows only when `kDebugMode` and the
  reminders coordinator is there; release builds never build it. It sits at
  the bottom of About, in a SettingsSection-style box titled "Debug". Its
  buttons:
  - **"Anniversary notice for…"** opens a date picker, then
    `coordinator.showAnniversaryNow(day)`. That shows the notice for that
    day at once (id 900), with the real text and payload, so a tap opens
    the filtered list. With no anniversaries that week, the text says so.
  - **"Practice reminder now"** calls `coordinator.showReminderNow()`,
    which shows the real reminder (id 901) with its payload.
- `ReminderScheduler.showNow(id, title, body, payload)` shows a
  notification immediately. The fake records it.
- **Reaching About.** AboutScreen gets `reminders` (optional). Both the
  list and Settings pass it. In Settings it is already a field.

## Tests

- Core: `textFor` ordering, the cap, "today", unnamed people, and the
  week bounds.
- App:
  - the coordinator schedules texts per day;
  - a renamed person reschedules (the cache key);
  - the Settings text;
  - the debug section shows in tests (kDebugMode is true there) when
    reminders exist, and its buttons call `showNow` with the right payloads;
  - no section without reminders.

## As built (after Plan check and Gate; supersedes the design above)

- **Wording (grace).**
  - Warm sentences, at most three names, then "And N more.":
    "Ann Lee's birthday is today. Bo has an anniversary on Saturday."
  - Only birthday, wedding and first met are said aloud. Any other type,
    a loss or one Fred made up, gives only "has an anniversary".
  - No name reads "Someone you met has a birthday today."
- **Lock screen (sally).**
  - A new channel, `anniversaries_named`, with `NotificationVisibility.
    secret`; the old channel is deleted. The text is big-text, so all of
    it shows.
  - iOS has no per-notice hiding in this plugin, so previews follow
    Fred's own setting; Settings and the policy say so.
- **Backup (sally, then fixed in Gate).** The plugin keeps scheduled
  notices, names included, in `shared_prefs/scheduled_notifications.xml`.
  It is excluded from backup and from device transfer.
- **Logs.** Every log on the reminder paths prints only the error's type.
- **Debug.** `DebugSection`, built only when `kDebugMode`. Its buttons
  show the real notice for a picked day, and the practice reminder, at
  once (ids 900 and 901).

