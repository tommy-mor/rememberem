# Story 14: Daily practice reminders

## Goal
Fred can opt in to one generic reminder a day. Tapping it opens a practice game directly, with back returning to the list. Everything stays on the device and nothing is named on the lock screen.

## Acceptance criteria
1. Reminders are off by default. No permission prompt appears until Fred turns the switch on, including at launch with default settings.
2. A Reminders screen, reached from the list app bar, has a switch and a time row (default 19:00).
3. Turning the switch on requests notification permission. If denied, the switch stays off and shows text explaining that notifications are blocked, with a button to open system settings.
4. While on, exactly one notification a day is scheduled at the chosen local time. Changing the time replaces the schedule. Turning the switch off cancels it.
5. The title and body are fixed generic text ("Time to practice", "A minute to practice remembering people"). The payload is only a game id (`faces` or `details`). No names, places, meetings or details appear. The channel has private lock-screen visibility.
6. Tapping the notification, cold or warm, opens a game on top of the list. Back returns to the list, and no capture screen is left beneath. A reminder never starts while the capture screen is open.
7. The game is chosen at tap time: the first playable game in the order faces, details (deterministic, no persisted alternation). If none is playable (no active people, or too few), the list opens. Trashed people do not count.
8. A second tap while a game is open or loading does not stack a second game. A tap while an edit screen is open keeps the typed edit (the edit screen's dispose flush). A tap while a capture is open (idle or saving) is ignored, and the person is never discarded. The next reminder is the retry.
9. The setting survives restart. A missing or corrupt settings file loads as off without throwing.
10. The schedule is reasserted on every app open (also after the time zone or DST changes), and after a reboot or app update.
11. If a successful repository read at app open shows nothing playable, the schedule is cancelled (without writing enabled=false) and the screen says reminders resume when there are enough people. It is restored on the next open when something is playable, as long as the switch is still on. If the read throws, the existing schedule is left unchanged.
12. The app makes no network calls.
13. A null, empty, unknown or forged payload arriving through the tap path is ignored: the list stays, nothing throws, and a later valid tap still works.

## Design

### Core (pure Dart, `packages/rememberem_core/lib/src/`)
- `reminder_settings.dart`: immutable `ReminderSettings {enabled, hour, minute}`. `off()` returns the default (false, 19:00). `toJson`/`fromJson` is tolerant: any bad shape returns `off()`.
- `practice_game.dart`: `enum PracticeGame { faces, details }` with a `wireId` and `fromWireId` that returns null for unknown values. Reuse the game enum or id that stories 10 and 11 define rather than declaring a second one; replace this with their real symbols once they land.
- `reminder_target.dart`: `ReminderTarget.resolve(List<Memory> active, PracticeGame? requested)` returns the first playable game or null. It uses the playability predicates from stories 10 and 11 (story 11 defines `canPlay`: at least 4 active people and a pair), reusing them rather than redefining the rules. Their names and shapes are unverified until those stories land. A requested game is honoured only if it is still playable.
- Export all three from `rememberem_core.dart`.

### App (`app/lib/src/reminders/`, one class per file)
- `reminder_scheduler.dart`: abstract `ReminderScheduler` with `Future<bool> requestPermission()`, `Future<bool> hasPermission()`, `scheduleDaily(hour, minute)` (replaces any existing), `cancel()`, `Future<PracticeGame?> launchGame()` (the game from a cold-start launch, once), and `Stream<PracticeGame?> taps` (null for an unparseable payload).
- `local_notifications_scheduler.dart`: adapter over `flutter_local_notifications` and `timezone` (with `flutter_timezone` to find the zone name).
  - Uses `zonedSchedule` with `matchDateTimeComponents: time` and `AndroidScheduleMode.inexactAllowWhileIdle`. It never requests SCHEDULE_EXACT_ALARM or USE_EXACT_ALARM.
  - Initialises the tz database and sets the local location once, in the adapter's init (called from `sync()`), inside try/catch.
  - Cold and warm taps use different plugin APIs (`getNotificationAppLaunchDetails` and the response callback). Both feed one shared handler with a single-fire guard. The handler maps a null from `PracticeGame.fromWireId` to ignore.
  - Channel `practice`, `visibility: private`, with a `publicVersion` that is generic.
  - Errors are swallowed to `false` and never block startup.
- `fake_reminder_scheduler.dart` goes in `app/test/fakes/`. It records calls and exposes `emitTap` and `launch`.
- `reminder_settings_store.dart`: abstract store. `file_reminder_settings_store.dart` writes `reminders.json` atomically (temp plus rename) in documents, and `load()` returns `off()` on any failure.
- `reminder_coordinator.dart`: owns the settings and the scheduler.
  - `sync`, `setEnabled` and `setTime` all run through one serial chain inside the coordinator (baseline invariant 6, serial saves, is the precedent). After its repository read, `sync` re-reads the current settings before it schedules, so a disable that lands mid-sync wins.
  - `sync()` resolves the repository, then schedules or cancels (criterion 11). Cancelling for emptiness happens only after a successful read showing nothing playable, and only in `sync`. If the read throws, the existing schedule is left unchanged. Cancelling never writes enabled=false.
  - `sync()` checks `hasPermission` when enabled. If revoked, it persists off, cancels and does not schedule. With default off settings it makes no `requestPermission` or `scheduleDaily` call (at most a cancel).
  - `setEnabled(bool)` requests permission, and if denied persists off and returns a denied result. `setTime(h, m)` persists and re-syncs.
- `reminders_screen.dart`: the switch, a `showTimePicker` row, the denied explanation with an "Open settings" action, and the "resumes when there are enough people" note. The system-settings action is a method on the scheduler, not a new plugin.
- `AppServices` gains `ReminderCoordinator? reminders` (null in tests). `main.dart` builds the real one, wraps it in try/catch, and calls `sync()` unawaited after the first frame.

### Routing (`rememberem_app.dart`)
- Extract `_openOnRoot(WidgetBuilder)`, which has the navigator null guard, the shared `_busy` flag (replacing `_capturing`), `popUntil(isFirst)` and `push`. `_busy` is cleared in `finally`, as `_meetSomeone` does today. `_meetSomeone` and the reminder route both use it.
- `_openReminder(PracticeGame? requested)` is wrapped in try/catch so the taps subscription survives. A null request is ignored. Otherwise it loads active people, calls `ReminderTarget.resolve`, and pushes the game screen, or does nothing if null (the list stays).
- Cold start: in `initState`, `addPostFrameCallback` first subscribes to `taps`, then awaits `launchGame()` and routes to the result. Subscribing first means a tap during the await is not lost.
- Dropped taps: there is no deferral queue, no cross-class `ValueNotifier` and no `CaptureScreen` constructor parameter. `capture_screen.dart` leaves capture by `pushReplacement` and resets `_saving` only on the error path, so a deferred replay would misfire. A tap while `_busy` is ignored, as the existing trigger already ignores a second one.
- State table for a reminder tap:

| Screen state | `_busy` | Reminder tap |
|---|---|---|
| List | no | opens the game |
| Edit screen open | no | `popUntil` runs, the dispose flush keeps the edit, the game opens |
| Capture open (idle or saving) | yes | ignored |
| Reminder game loading or open | yes | ignored |

- The Android activity is `singleTop`, so a warm tap arrives through the plugin's response callback. No manifest change is needed for this.
- The edit screen already flushes in `dispose` (`memory_edit_screen.dart:70`) and on inactive (:50), so no code change is needed under `popUntil` (baseline risk 20). Add a regression test that proves the edit is not lost.

### Platform
- `pubspec`: `flutter_local_notifications`, `timezone`, `flutter_timezone`, each pinned to an exact version already compatible with Dart in this repo.
- Android manifest: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and the plugin's `ScheduledNotificationBootReceiver` and `ScheduledNotificationReceiver`, both `android:exported="false"`. Core library desugaring is mandatory: set `isCoreLibraryDesugaringEnabled = true` in `compileOptions` and add the `coreLibraryDesugaring` `desugar_jdk_libs` dependency in `android/app/build.gradle.kts` (check compileSdk and AGP satisfy the plugin). This is the first build step, verified with a debug build before other code. No exact-alarm permission.
- Release gates (all recorded in `baseline.md`):
  1. Diff the merged release manifest (permissions and exported components) against the baseline. The only expected additions are POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED and the two non-exported receivers. Any other new permission fails the story.
  2. Read the sources of `flutter_timezone` and the other new plugins for network calls (invariant 12). If this fails, fall back to a small platform-channel read of the zone id behind the scheduler interface.
  3. Confirm applicationId and signing are unchanged, and bump the version for the release.
- Exclude the plugin's SharedPreferences from backup only if a backup rules file is added by a later story. Note this in risks.
- iOS: request alert permission through the plugin only on enable.

## Tests
- `reminder_settings_test.dart` (core): bad JSON, a missing file or wrong types give `off()`. Round trip preserves hour and minute.
- `reminder_target_test.dart` (core): returns the first playable game. A requested but unplayable game falls through. Trashed people are not counted. Empty gives null.
- `reminder_coordinator_test.dart`:
  - Enabling at 19:00 gives exactly one `scheduleDaily(19,0)`. Changing the time gives one replacement, not two. Disabling calls `cancel`. Denied permission leaves `enabled` false and persists off.
  - `sync` with no playable game cancels. `sync` with a playable game and the switch on re-schedules.
  - A repository read error leaves the schedule alone. Empty then playable restores the schedule.
  - `sync()` on default off settings makes zero `requestPermission` and `scheduleDaily` calls, and at most a cancel.
  - Enabled settings plus `hasPermission` false: `sync` persists off, cancels, and does not schedule.
  - A restored enabled file on a fresh install schedules only if permission is held, and otherwise lands on off with no prompt at launch.
  - Serialization: with a slow fake repository, `sync` starts, then disable, and the final state is cancelled.
- Privacy test: with a repository holding a distinctive name, place, meeting and detail, the scheduled title, body and payload contain none of those strings.
- `reminders_screen_test.dart` (widget): the switch is off by default. Toggling on with permission shows the time. Toggling on when denied leaves it off and shows the explanation text. The time picker updates the fake.
- `reminder_routing_test.dart` (widget):
  - A cold payload present before the first frame ends on the game once, and back lands on `MemoryListScreen`. A warm tap does the same. Two taps in a row give one game.
  - A tap with nothing playable leaves the list.
  - A tap while the edit screen is open keeps the typed edit (regression test only).
  - The real tap wiring is tested: the launch details and the response callback feed one shared handler that fires once.
  - A tap during a capture save is ignored and the person is not discarded.
  - A tap while the camera is open and idle is ignored and the camera stays.
  - A tap after a completed capture still opens a game.
  - Unknown, empty and null payloads: the list shows, nothing throws, and a later valid tap still opens a game.
- Store test: write then read returns the same value. Corrupt file gives `off()`.

## Risks and mitigations
- Cold-start race: the payload is read after the first frame and replayed, with the taps subscription made first. Covered by a test.
- Empty-state reminder: the game is resolved at tap time, and the schedule is reasserted on every open.
- Denied or revoked permission: `sync` checks `hasPermission`. If revoked, it persists off and the screen shows the explanation.
- Reboot, DST and zone change: the boot receiver, `matchDateTimeComponents.time`, and the schedule reasserted on open.
- Inexact delivery can be late. The screen says "around" this time.
- A fixed time on a trashed-everything day sends a no-op reminder at worst, never one that reveals data.
- A reminder tap during capture is dropped. Accepted: the next reminder is the retry.
- The notification activity is exported, so the payload is untrusted. Unknown values are ignored.
- The plugin's SharedPreferences are in Android backup (baseline risk 6). They hold only the schedule and generic text, never person data.
- A plugin that adds network behaviour: not expected, enforced by the release gate above (invariant 12).
- Story 13 back behaviour depends on the shared `_openOnRoot`. Do not bypass it.

## Out of scope
Streaks, counts and guilt wording. Several reminders a day or per-weekday schedules. Choosing a game in settings. Alternating games with persisted state. Exact alarms. Snooze or action buttons. Backup rules and screen-privacy hardening (existing risks 6 and 16). Showing a face or a name in a notification.

## Baseline record changes
- Story 14 entry: opt-in daily reminder (`ReminderCoordinator`, `ReminderScheduler`, `ReminderSettings`, `reminders.json`), a generic payload of a game id only, a game chosen at tap time, rescheduled on every open, and routing through the shared `_openOnRoot`.
- Manifest line: add POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED, plus two non-exported plugin receivers. Record the merged-manifest diff.
- "Absent" line: remove "reminders".
- Invariant 8 now covers the reminder route as well as the shortcut.
- Invariant 12: the notification plugins add no app network code, recorded against the source-read gate.
- Unverified: if the cold-start shortcut check was never run, note that the reminder uses the post-frame replay and the shortcut still does not.
- Risk 6: the plugin's SharedPreferences is in backup.
- Risk 20: the reminder route also uses `popUntil`.

## Review record
Crews and agents: a guardian crew (three guardians), builders, and Vera as settlement editor. No TieBreaker was needed.

Objections and settlements (all agreed, no stalemates):
1. Defer versus drop a tap during capture save. Settled: drop. The deferral queue, cross-class notifier and `CaptureScreen` parameter are removed (criterion 8). Evidence: `pushReplacement` in `capture_screen.dart:79` and `_saving` reset only on error at :91.
2. Coordinator serialization and subscribe order. Settled: one serial chain, `sync` re-reads settings before scheduling, subscribe to `taps` before awaiting `launchGame()`. Test added.
3. `_busy` lifecycle and camera-open-idle tap. Settled: state table added, criterion 6 reworded, `finally` clears `_busy`, test added.
4. Cancel when nothing playable. Settled: cancel only after a successful read, read error leaves the schedule, cancel never writes enabled=false (criterion 11). Tests added.
5. Missing coordinator tests (default-off launch, revoked permission, restored file). Settled: three tests added.
6. Manifest receivers and plugin network check. Settled: `exported="false"`, merged manifest diff gate, exact version pins, source-read gate with platform-channel fallback, no exact-alarm permissions, applicationId and signing confirmed.
7. Null, empty or forged payload. Settled: `taps` carries `PracticeGame?`, null is ignored, `_openReminder` is try/catch wrapped (criterion 13). Test added.

Rulings: none (`docs/reviews/rulings/` precedent was not invoked; no stalemates).

Unverified:
- The names and shapes of the stories 10 and 11 playability predicates and game enum.
- Whether `flutter_timezone` and the other plugins make network calls (a release gate, nothing opened in the pub cache).
- Plugin versions compatible with the repo's Dart and AGP.
- `docs/reviews/baseline.md` was not re-read while applying this settlement; line references to `rememberem_app.dart`, `capture_screen.dart` and `memory_edit_screen.dart` come from the settlement's evidence.
- No builds, tests or devices were run (planning only).
