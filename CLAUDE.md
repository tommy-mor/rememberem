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
- `app/` is the Flutter app. Under `lib/src/`: `app/` holds the shell, services
  and the "Meet someone" shortcut; `capture/` the camera and ML Kit face
  detection; `memories/` the list, the notes screen and the autosaving
  `MemoryEditor`; `speech/` the `Dictation` interface and mic text fields;
  `location/` the GPS lookup.
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
- `detailItems` is an ordered list of details, each `{id, text, at}` with `at`
  in UTC: the time the detail was recorded (Fred can re-date it). Records
  written before it existed kept one `fields['details']` string. That string
  loads as a single detail timed at the first encounter, and the key is
  dropped on the next save.
- `trashedAt` marks a person as in the trash. `all()` returns only active
  people; purge deletes every `<id>.*` file and refuses anyone not in the
  trash.
- Photos are made upright, cropped to a 4:5 head-and-shoulders portrait around
  the largest face, and never written to the gallery.

### Privacy questions still open

Check these before any public release. `sally` and `lena` own them.

- **Speech:** the platform recogniser may send audio to Google or Apple servers
  unless on-device recognition is used.
- **Backups:** Android auto-backup and iOS iCloud backup may copy the
  `memories/` folder off the device.
- **Faces:** face detection runs on-device through ML Kit. Laws on biometric
  data, such as BIPA, may still apply to storing faces of people who are not
  users.

## Platform gotchas

- **Windows Android builds:** `app/android/gradle.properties` sets
  `kotlin.incremental=false`. Without it, builds fail when the project (`F:`)
  and the pub cache (`C:`) are on different drives.
- **iOS:** builds need a Mac with Xcode. The minimum is iOS 15.5 because of ML
  Kit (see `app/ios/Podfile`). Permission prompt text is in
  `app/ios/Runner/Info.plist`.
- **Screenshots from a device:** run `adb exec-out screencap -p > file.png` from
  Bash. PowerShell's `>` corrupts binary output.
- **Launching the shortcut by hand:** the extra's key contains spaces, so quote
  the whole command:
  `adb shell "am start -a android.intent.action.RUN -n com.rememberem.rememberem/.MainActivity --es 'some unique action key' meet_someone"`.
- **Test portrait:** `app/integration_test/assets/portrait.jpg` is a
  public-domain NASA portrait for the on-device face test. It is bundled as an
  app asset, so it also ships in release builds.
