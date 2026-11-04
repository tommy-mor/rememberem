# Rememberem

## North star

**Help me to be a force for good in the world by remembering people I meet and
the details that make them special.**

Every change is measured against this. A feature earns its place if it helps
someone remember another person: their name, where you met, what matters to
them. It also has to treat that person with respect. Each record is about a real
human being who trusted the user enough to be photographed. If a change makes
remembering easier but would embarrass, expose, or misuse the person in the
photo, it fails the north star.

What follows from it:

- **Fast at the moment of meeting.** The user is mid-conversation. From the
  shortcut to a saved photo and spoken notes, there must be no friction and no
  fiddling.
- **Private by default.** Photos and notes stay on the device, in app-private
  storage. Nothing is uploaded, shared, analysed for advertising, or sold.
- **Practice that builds real memory.** Reminders exist to help the user learn
  names. They should never feel like nagging or engagement bait.
- **Kind to the person in the photo.** Consent comes first, and notes should
  stay fit for the person to read.

## Quality bar: rigorous multi-agent testing

**This project overrides the global "fewer agents" guidance for check-ins and
deployments.** Reviews still pick the cheapest model that is good enough. They
are not skipped.

### Before every check-in (commit)

1. **Automated checks, all green**, even for a docs-only change. No check may
   be skipped or assumed. Run from the repo root:
   ```sh
   (cd packages/rememberem_core && dart analyze && dart test)
   (cd app && flutter analyze && flutter test && flutter build apk --debug)
   ```
2. **Run the Gate crew** from
   [.claude/agents/REVIEW_AGENTS.md](.claude/agents/REVIEW_AGENTS.md). Each
   reviewer runs as its own subagent, they run in parallel, and `vera` always
   goes last. A code change gets `hal` and `tess`, plus the specialists the
   change calls for. A docs-only change gets `daphne` → `vera` instead.
   If `.claude/agents/` has only `REVIEW_AGENTS.md`, generate the agent files
   first, following its Installing section.
3. **Fix or explicitly accept** every Blocker and Should-fix that `vera`
   confirms. Then re-run the checks.
4. **Say what ran in the commit message:** the crew, what `vera` confirmed, and
   anything not verified. An unrun check is never reported as a pass.

### Before every deployment

A deployment is anything that puts a build in someone else's hands: an app store
release, TestFlight, Play testing tracks, or a sideloaded build for a friend.

1. Everything in the check-in list.
2. Integration tests on an emulator **and** a real device:
   `flutter test integration_test -d <device>`.
3. `fred` (as part of the Release readiness crew below) walks the full user story on a real device, from the shortcut through
   capture to every spoken field, and confirms the data survives restarting the
   app.
4. **Run the Release readiness crew** → `vera`. It recommends ship, ship with
   stated risks, or hold.
5. **Eric deploys.** A recommendation to ship is not permission to ship.

### Crews

The review crews are defined in
[.claude/agents/REVIEW_AGENTS.md](.claude/agents/REVIEW_AGENTS.md). When Eric
names a crew, run its agents as parallel subagents with distinct questions and
finish with `vera`.

The **Baseline** crew (the guardians) and the **Plan check** crew (the builders)
share no members and are deliberately adversarial. To save tokens, plan each
story with a slimmed lineup (about three guardians and two or three builders,
chosen by lane; see "Slim by default" in REVIEW_AGENTS.md). Every plan goes through Plan
check, then gets objections from Baseline, with one round of rebuttals each way.
`vera` settles the factual disputes. Any stalemate left over goes to the
**TieBreaker** crew: `paige` (product manager, chair), `walt` and `hazel`
(long-view generalists). Their rulings are saved in `docs/reviews/rulings/` and
treated as precedent. Eric can overrule any ruling, and stalemates over data
loss, data leaving the device, or harm to the person in the photo go straight to
him. Give each agent a model per the global rules: `haiku` for
mechanical checks, `sonnet` for judgement. Use `opus` only when a cheaper model
has already been tried and fallen short.

## Stack and layout

- **Flutter** (stable, 3.47+, Dart 3.13+) for Android and iOS. On Eric's Windows
  machine the SDK is at `C:\src\flutter\bin`, which is not on PATH by default.
- `packages/rememberem_core/` holds pure Dart with no Flutter: the `Memory`
  model, `JsonFileMemoryRepository`, `PortraitFramer` and `PortraitCropper`, and
  the `PortraitCapture` pipeline. Platform features enter through interfaces
  (`FaceLocator`, `MemoryRepository`), so all of this is unit-testable.
- `app/` is the Flutter app. Under `lib/src/`: `app/` holds the shell, services,
  theme and the "Meet someone" shortcut; `maps/` the street map and location
  picker; `settings/` the Settings page and store; `capture/` the camera and ML Kit face
  detection; `memories/` the list, the notes screen and the autosaving
  `MemoryEditor`; `speech/` the `Dictation` interface and mic text fields;
  `location/` the GPS lookup.
- `site/` is the website (homepage and privacy policy), published to
  https://nebosite.github.io/rememberem/ by `.github/workflows/pages.yml` on
  a push to main that changes it.
- **Code style:** object-oriented, one class per file, YAGNI. Platform plugins
  stay behind small interfaces so tests can use fakes, as in `app/test/fakes/`.

## Data the app keeps

- One `<id>.json` per person in `getApplicationDocumentsDirectory()/memories/`,
  plus one photo per encounter: `<id>.jpg` for the first, and
  `<id>.<source>.jpg` for photos merged in from someone else. Writes go to a
  temp file and are then renamed into place, and every mutation goes through
  one serial chain in `JsonFileMemoryRepository`.
- `encounters` lists every time Fred met the person, each
  `{photo, capturedAt, location, place, meeting}`, kept newest first. The
  newest encounter's photo represents the person everywhere. Records written
  before encounters kept one top-level `photo`/`capturedAt`/`location`, with
  place and meeting in `fields`. They load as one encounter.
- `fields` is an open map holding the name. **Adding keys needs no migration;
  renaming or removing keys does,** and the change must still load records
  written by older versions.
- `detailItems` is an ordered list of details, each `{id, text, at}` (plus
  `points` and `lastCorrectDate` once practised) with `at`
  in UTC: the time the detail was recorded (Fred can re-date it). Records
  written before it existed kept one `fields['details']` string. That string
  loads as a single detail timed at the first encounter, and the key is
  dropped on the next save. A detail's `text` may be blank once it has other
  data (a relationship's person or type, a place, a date); only a detail
  with nothing entered, or a tag with no tag type and no text
  (`Detail.isEmpty`), is left out of a save.
- Each detail has a `type` (fact, happening, relationship, anniversary or
  tag). A tag keeps its tag type in `label` and an optional `place` and
  `eventDate`; tags are never practice questions.
  Records written before typed details have no `type` and read as facts.
  Relationships keep the other person's id in `targetId`; merge and purge
  repoint or clear it in every record. Relationship and anniversary types
  are derived from the data, never stored.
- `points` and `lastCorrectDate` on a person (face practice) and on a detail
  (details practice) are left out of the file until used. They change only
  through `recordAnswer` and `recordDetailAnswer`, and `save()` keeps the stored
  values, so a card autosave never undoes a game result.
- An encounter with no location and place `Remote` happened online. It is
  never matched to a real place.
- Meetings auto-fill by place plus local time of week (a weekly meeting),
  within the window set in Settings.
- `settings.json` (`AppSettings`) holds Fred's settings. Colours saved
  before story 28 read as their new values (`AppPalette.legacyBackgrounds`
  and `legacyThemeColors`), and a dark background makes dark pages; `reminders.json`
  holds the reminder and the anniversary-notices switch (missing in older
  files: it follows the reminder switch). Damage in either never stops the
  app.
- `settings.json` may also hold `placeRadii` (a place's own radius in
  metres, keyed by its trimmed name; a rename carries it), `placeSpots`
  (where Fred moved a named place on the Places map, keyed the same way;
  photos keep their own GPS, and the place is drawn and matched at its
  spot), `placeNotify` (Fred's Notify box per place, keyed the same way;
  missing: on, except home, work and church; a rename carries it), and
  `metricUnits` (missing: by the phone's region; feet and miles in the US,
  Liberia, Myanmar and the UK).
- `rememberedThreshold` defaults to 10 (range 3–20); a stored value is
  kept.
- Anniversary notices are scheduled 30 days ahead on each sync (app open,
  resume, back to the list), ids 100–129, at 09:00 on each day whose next
  week holds an anniversary. They name who (`AnniversaryNotice.textFor`:
  a birthday, wedding or first met is said, any other type only as "an
  anniversary"; at most three names), on the `anniversaries_named` channel
  with secret lock-screen visibility; their text is never logged, and the
  plugin's store of them (`scheduled_notifications.xml`) is left out of
  Android backup. A tap returns to
  the list with an Anniversary filter for that week.
- The list's filters and sort (`ListFilters` on `AppServices`) are not
  saved: a restart shows everyone, newest first.
- Place notices (`ReminderSettings.places`, off by default and never on
  without the `PlaceNoticeConsent` page) watch the named places with the
  phone's geofencing (`native_geofence`, behind `PlaceFences`), at least
  100 m, the 90 newest of those whose Notify box is ticked (arrival
  checks the box again). Fences carry only an opaque id
  (`PlaceNotice.fenceId`, a hash of the name), so no name reaches the
  plugin's store or logs. On arrival (Android: a 3-minute stay; iOS:
  entering), `placeArrived` runs in the background, builds what it needs
  through `AppFiles`, and `PlaceArrival` shows "At Cafe: You've met Ann
  here." at most once a place per 12 hours (`place_notices.json`, ids
  only). A tap filters the list to the place. The plugin's store and
  `place_notices.json` are left out of backup. No foreground service.
- `contactKey` (top level, optional) links a person to a phone contact by
  Android lookup key only; no contact data is copied. It changes only through
  `setContactKey`, so autosave never undoes it.
- `trashedAt` marks a person as in the trash. `all()` returns only active
  people; purge deletes every `<id>.*` file and refuses anyone not in the
  trash.
- Photos are made upright, cropped to a 4:5 head-and-shoulders portrait around
  the largest face, shrunk to 1000 px on the long side at JPEG quality 75,
  and never written to the gallery.
- A record file that can't be read is skipped, not fatal, and left on disk.
  The list says how many were skipped (`MemoryRepository.unreadable`).

### Privacy questions still open

Check these before any public release. `sally` and `lena` own them.

- **Background location:** place notices declare
  ACCESS_BACKGROUND_LOCATION, so every Play release needs the location
  permissions declaration, a video and the in-app disclosure (the consent
  page). Play may judge it not core and reject the release. Eric files.
  iOS is unbuilt and untested.
- **Speech:** dictation requests on-device recognition (`onDevice: true`).
  Without an on-device recogniser (before Android 12, or none installed) the
  phone's speech service may still send audio to Google or Apple servers.
  About and the privacy policy say so.
- **Backups:** on, Eric's call: Android auto-backup copies the `memories/`
  folder to the user's Google backup (25 MB per app, then it stops). About
  and the empty list say so. iOS iCloud backup is unsettled.
- **Map tiles:** with Street maps on (the default, Eric's call), OpenStreetMap
  sees the device IP, the user agent and the area being viewed. It never sees
  names, photos or notes. Settings can turn this off.
- **Imported photos:** reading a photo's GPS needs `ACCESS_MEDIA_LOCATION`,
  which Android presents as photos and videos access (with a "limited
  access" choice). It is asked on each gallery tap until allowed or Android
  stops asking. Photos come through the phone's gallery app, which may be a
  cloud app (Google Photos) that sees the choice.
- **Contacts:** linking uses only the system contact picker, which grants
  access to the one contact chosen. There is no READ_CONTACTS permission.
- **Faces:** face detection runs on-device through ML Kit. Laws on biometric
  data, such as BIPA, may still apply to storing faces of people who are not
  users.
- **Privacy policy:** `site/privacy.html`, published by GitHub Pages at
  the URL in `AboutScreen.privacy`. Privacy questions go to
  rememberem@niftibits.com. Keep it, About and the Data safety form saying
  the same thing.

## Platform gotchas

- **Windows Android builds:** `app/android/gradle.properties` sets
  `kotlin.incremental=false`. Without it, builds fail when the project (`F:`)
  and the pub cache (`C:`) are on different drives.
- **iOS:** builds need a Mac with Xcode. The minimum is iOS 15.5 because of ML
  Kit (see `app/ios/Podfile`). Permission prompt text is in
  `app/ios/Runner/Info.plist`.
- **Release signing:** `app/android/key.properties` (git-ignored) names the
  upload key. Without it a release build stops, unless built with
  `-PallowDebugSigning=true`, for a release walk on your own devices only. See `docs/release-steps.md`.
- **Release builds shrink code:** they can break plugins that use reflection,
  and debug builds don't show it. ML Kit face detection crashed, and scheduled
  notifications silently never scheduled, until the keep rules in
  `app/android/app/proguard-rules.pro` were added. The notification icon is
  kept by `res/raw/keep.xml`. Before any deployment, install a **release** APK
  and walk capture and a reminder on a device.
- **Screenshots from a device:** run `adb exec-out screencap -p > file.png` from
  Bash. PowerShell's `>` corrupts binary output.
- **Launching the shortcut by hand:** the extra's key contains spaces, so quote
  the whole command:
  `adb shell "am start -a android.intent.action.RUN -n com.rememberem.rememberem/.MainActivity --es 'some unique action key' meet_someone"`.
- **Branding:** the images come from `app/assets/branding/` through
  `app/tool/make_branding.py`, then `dart run flutter_launcher_icons` and
  `dart run flutter_native_splash:create`. Game sounds come from
  `app/tool/make_sounds.py`.
- **Photo GPS on Android:** the system photo picker strips location, so
  photos from the phone come through `OriginalPhotoPicker.kt`, which opens
  the phone's gallery (`ACTION_PICK`) and asks `MediaStore.setRequireOriginal`
  for the unredacted file. If it cannot, it says so (`original: false`) and
  the app explains how to allow it. Google Photos returned GPS on the
  emulator even without the permission; Samsung Gallery is unverified.
- **Sounds and haptics:** sounds use the media volume (the ringtone stream
  is silent on vibrate), and the right-answer buzz goes through `Haptics.kt`
  as a media vibration: Flutter's haptics are touch vibrations, which follow
  the "touch interactions" setting many phones ship turned off.
- **Test portrait:** `app/integration_test/assets/portrait.jpg` is a
  public-domain NASA portrait for the on-device face test. It is bundled as an
  app asset, so it also ships in release builds.
