# 15. Polish batch: branding, maps, locations, imports, quizzes, settings

Twelve small changes Eric asked for in one go, planned and checked together
with a minimal crew. Each item lists acceptance criteria (AC) and design.

## 1. Branding: splash, launcher icon, in-app logo, colours

AC: the launch splash shows the gold elephant on navy; the launcher icon is the
elephant; the list screen's app bar shows the "Remember'em" text logo instead of
the word "Rememberem"; the whole app uses navy and gold.

Design:
- Move `app/assets/logo full.png` and `Logo text.png` to
  `app/assets/branding/logo_full.png` and `logo_text.png` (no spaces). Commit
  the 2–3 MB originals only as build inputs for icons and the splash. Ship
  downscaled copies: `logo_text_small.png` (about 900 px wide) for the app bar,
  and `elephant_mark.png` (the elephant cut out on a transparent background,
  1024 px, made with a short Python/PIL script kept in `tool/`).
- Dev dependencies `flutter_launcher_icons` and `flutter_native_splash`,
  configured in `pubspec.yaml`. Android adaptive icon: navy background
  `#0A2A7A`, elephant foreground. Splash: navy background with `logo_full.png`
  centred; on Android 12+, the elephant mark in the system circle. iOS gets
  the same via the generators (not buildable here; unverified).
- `RememberemTheme` (`app/lib/src/app/rememberem_theme.dart`): a Material 3
  `ColorScheme` with primary navy `#0A2A7A`, secondary and tertiary gold
  `#E4BC52`, and app bars navy with gold text and icons. FABs and filled
  buttons use gold on navy. Replace the teal seed.
- `BrandLogo` widget: `Image.asset('assets/branding/logo_text_small.png')`
  at app-bar height, with semantics label "Rememberem" so tests and screen
  readers still find the name.

## 2. Clock icon for the timeline

`Icons.schedule` replaces `Icons.timeline` on the list's Timeline button.

## 3. Name defaults to "Unknown"

AC: someone with no name shows as "Unknown" everywhere a name is shown (list,
places, merge picker, matching, games). The Name field on the card shows the
hint "Unknown". Nothing is written to the record, so the face game still treats
the person as unnamed and the "4 named people" rule is unchanged.
Design: `MemoryTile.nameOf` returns `'Unknown'`, and `DictatedTextField` gains
an optional `hint`.

## 4. Places map: street map, photos by names, tap a person to open the card

AC: the Places map shows OpenStreetMap streets with attribution. Each place
marker is labelled. Selecting a place lists its people with a round photo
beside each name, both in the expanded list row and in a small card over the
map. Tapping a person opens their person card. Back returns to Places with the
same place selected.

Design:
- Add `flutter_map` and `latlong2`. A `StreetMap` widget wraps `FlutterMap`
  with an OSM `TileLayer` (`userAgentPackageName: com.rememberem.rememberem`)
  and `RichAttributionWidget`. It takes markers and an optional centre. When
  street maps are off in Settings, it draws no tile layer: markers sit on a
  plain background, which keeps the old no-network map.
- `PlacesMap` is rewritten on top of `StreetMap`. `PlaceMapPainter` and
  `PlaceMapProjection` are deleted once nothing uses them.
- `PlaceRow` (expanded) and `PlacePeopleCard` (over the map) list people as
  `CircleAvatar(FileImage)` plus the name. Tapping one pushes a
  `PersonCardRoute`, so `PlacesScreen` needs `AppServices`.
- Privacy note for CLAUDE.md: map tiles are fetched from OSM servers, so the
  map area being viewed leaves the device. No names, photos or notes are sent.
  Eric asked for this; Settings can turn it off.

## 5. Reminders on by default

AC: on a fresh install, reminders are on at 19:00. The notification permission
is asked once, at a calm moment: the first time the list shows with at least
one person (never over the camera). If it is denied, reminders turn off and
are never asked for again (the existing rule).

Design:
- `ReminderSettings.defaults()` replaces `.off()` as the "nothing stored"
  value: enabled, 19:00. Unreadable stored values still fall back to it.
- `ReminderSettingsStore.load()` reports whether anything was stored, through a
  new `hasSaved()`.
- `ReminderCoordinator.sync()` never asks for permission itself.
  `ReminderCoordinator.askOnce()` requests permission once if nothing is
  stored, saves `enabled = granted`, then syncs. `MemoryListScreen` calls it
  after a reload that finds at least one person, when the list route is
  current.

## 6. Map pin button to pick a location, with "Remote"

AC:
- A map-pin button sits beside the coordinates (or "No location") under the
  photo on the person card, and beside the date on each Picture screen.
- It opens the location picker: a street map centred on the picture's location
  (else the device location, else the newest known place), with a centre
  crosshair and every known named place highlighted as a labelled dot.
- "Use this location" sets the encounter's location to the map centre. A
  prominent "Remote" button sets the location to null and the place to
  "Remote". Back changes nothing.
- An encounter with no location is never matched to a real place. The place
  finder already skips null locations, and the plan adds a test.

Design:
- `Encounter.withLocation(GeoPoint?)`, with a `_copy` that can set null (a
  sentinel or a separate constructor call).
- `MemoryEditor.updateEncounter` is already in place.
- `Encounter.remotePlace = 'Remote'`.
- `LocationPickerScreen` returns a `LocationChoice`: either `point(GeoPoint)`
  or `remote()`.
- The card's caption becomes a `Row`: date and time text, a clock button
  (item 8), coordinates or "Remote" or "No location", and a pin button. Both
  buttons edit the newest encounter.
- `PlaceBook` keeps "Remote" as a named group with no marker. It already does
  this for null-location groups.

## 7. Use a picture from the phone

AC: the camera screen has a gallery button beside the shutter. Picking a photo
runs the same crop and save as a live shot. If the photo carries EXIF GPS
coordinates, they become the location, and the place and meeting auto-fill
from them. If it carries EXIF DateTimeOriginal, that becomes the picture time.
Otherwise the location is null (not the phone's current location, since the
photo may be old) and the time is now. The original file is never changed or
copied anywhere else.

Design:
- Add `image_picker` behind a `PhotoPicker` interface (`app/lib/src/capture/`).
- The core gets `PhotoMetadata.read(List<int> jpeg)` →
  `({GeoPoint? location, DateTime? takenAt})`, using the `image` package's
  EXIF decoder (`decodeJpgExif`), with GPS rationals converted and N/S/E/W
  refs applied. It is pure Dart, unit-tested with a JPEG built in the test
  with EXIF tags.
- Android: add `ACCESS_MEDIA_LOCATION`, needed on Android 10+ to read photo
  GPS. Risk: the Android 13+ system photo picker may strip GPS. Verify on the
  S22; if it does, fall back to `requestFullMetadata` / `ACTION_GET_CONTENT`,
  or say so in the UI.

## 8. Clock button to change a picture's time

AC: a clock icon button beside the picture time (person card caption and
Picture screen) opens date then time pickers and saves the new time. The
Picture screen's "Change date" text button is replaced by the icon.

## 9. Meeting matching by weekday and time of day

AC: a meeting recorded at "Park" on a Tuesday at 15:00 is suggested for a new
photo at "Park" on any Tuesday from 13:00 to 17:00 (the window from Settings,
default 2 h). It is not suggested on a Wednesday at 15:00, or at another place.

Design: `MeetingFinder.suggest` compares the local minute of the week
(weekday × 1440 + minute of day), using the circular distance modulo 10080, so
Sunday 23:30 is close to Monday 00:30. The window is a constructor parameter.
Ties go to the closest in week time, then the newest. Existing tests are
updated to match.

## 10. Quizzes never repeat an item

AC: within one game, no person (face game) or detail (details game) is asked
twice. A game has `min(turnsSetting, eligible count)` turns. If people change
mid-game so that nothing unasked is left, the game finishes early with the
score so far.

Design: both planners' `pickNext` take `Set<String> asked` (replacing
`previousId`) and pick only from the unasked; they return null when none are
left. The screens keep the set, and the turn total is fixed at game start.

## 11. Quiz feedback

AC:
- A right answer gives a light haptic tap and a short, sweet chime. The
  chosen button turns green, and the next question shows after 1 s.
- A wrong answer plays a soft, short "nope" sound. The button still disables,
  as today.
- No feedback plays while the app is in the background. Sounds and vibration
  each have a switch in Settings.

Design:
- `GameFeedback` interface with `right()` and `wrong()`. `DeviceGameFeedback`
  uses `HapticFeedback.lightImpact` and the `audioplayers` package playing
  `assets/sounds/right.wav` / `wrong.wav`, each about 0.4 s and under 40 KB,
  generated by a Python script in `tool/`.
- A fake for tests.
- `pauseAfterRight` is a screen parameter (1 s; tests pass zero or pump).

## 12. Settings page

AC: a gear button on the list's app bar opens Settings. It replaces the
Reminders button; the reminder controls move into Settings. Settings has:
- Reminders: the on/off switch and the time.
- Place matching distance: 100–1000 ft, default 300.
- Meeting time window: 30 min–4 h, default 2 h.
- Practice game length: 5–20, default 10.
- Face reveal time: 1–5 s, default 3.
- "Remembered" after N right answers: 3–10, default 5.
- Sounds and Vibration: both on.
- Street maps: on.

Changes save immediately and apply on the next use.

Design:
- Core `AppSettings` value with `fromJson` (each field validated and clamped;
  anything bad takes its default) and `toJson`.
- App `SettingsStore` interface plus `FileSettingsStore` (`settings.json`,
  temp-then-rename like the reminders store).
- `AppSettingsHolder` (a `ValueNotifier<AppSettings>`) in `AppServices`,
  loaded in `main` before `runApp`.
- `PortraitCapture.capture` takes `placeRadiusMeters` and `meetingWindow`
  arguments, or a settings getter. The caller passes the current values.
- `RememberedCount.of(active, threshold:)`.
- The game screens read turns, reveal time and feedback switches from
  settings.
- Reminder settings stay in their own store; the Settings screen reuses the
  reminders widgets.

## Tests

- Core:
  - `PhotoMetadata`: GPS N/E and S/W, no EXIF, no GPS, and DateTimeOriginal.
  - `MeetingFinder`: the same weekday a week later is in the window; another
    weekday is not; the window edges; wrap across midnight Sunday to Monday;
    another place is not.
  - `PlaceFinder` ignores an encounter with a null location named "Remote".
  - Planners: an exclusion set is never re-picked, and null is returned when
    exhausted.
  - `AppSettings` json round trip, plus clamping and defaults.
  - `Encounter.withLocation(null)`.
- App widget tests:
  - The location picker: Use returns the centre point; Remote returns remote;
    the card shows "Remote" afterwards.
  - The card's clock button updates the time.
  - Places: tapping a person opens the card. The street map is off in tests,
    so no network is used.
  - Games: no repeats in a 4-person game of 10 turns (4 turns); the fake
    feedback gets `right`/`wrong`; the next turn comes only after the pause.
  - Settings: changing the game length changes the turn count.
  - Reminders: defaults on; `askOnce` asks only once; a denial turns it off.
  - The list shows "Unknown" for an unnamed person, and the logo semantics.
  - Capture: the gallery path with a fake picker passes EXIF location and
    time to capture.
- Device (S22, debug build): splash, icon, a gallery pick with GPS, a street
  map, the pin picker and Remote, a quiz with sound and haptics, and the
  reminder permission prompt once.

## Risks

- Network now used for map tiles (privacy). Mitigation: the Settings switch;
  only tile coordinates are sent; documented in CLAUDE.md.
- Photo picker GPS stripping on Android 13+ (see item 7).
- `audioplayers` / `flutter_map` / `image_picker` in release builds: check
  the shrinker keep rules with a release APK.
- Changing `MeetingFinder` semantics changes old auto-fills only going
  forward; stored meetings are untouched.

## Out of scope

Details refactor and contacts (next stories).

## Baseline record changes

Record in baseline.md: map tiles fetched from OSM when street maps are on;
EXIF read from imported photos; Remote encounters; meeting matching by week
time; reminders on by default with a one-time permission ask; app settings in
`settings.json`.

## Amendments from the crew (binding)

Minimal crew: Sally (Baseline) and Archie (Plan check), in parallel. No
disputes needed Vera. Sally's "INTERNET is missing" was checked directly and
is refuted: `AndroidManifest.xml:4` already declares it.

1. **EXIF** (Archie, Sally).
   - `decodeJpgExif` takes a `Uint8List`.
   - GPS tags are rational triples: read `data[0x0002]` / `data[0x0004]` with
     `toDouble(0..2)` as degrees, minutes and seconds. The refs are `0x0001` /
     `0x0003`.
   - DateTimeOriginal is `exifIfd.data[0x9003]`, `"YYYY:MM:DD HH:MM:SS"`, read
     as local time.
   - Tests build `IfdValueRational` arrays by hand, the way phones write them.
   - `PhotoMetadata.read` never throws. It returns nulls for bad input (PNG,
     truncated bytes, zero denominators, NaN, latitude beyond ±90 or longitude
     beyond ±180), and for dates in the future or before 2000.
2. **Imported photos** (Sally).
   - `ACCESS_MEDIA_LOCATION` is requested only on the first gallery tap. A
     denial just means no location.
   - The plugin's cache copy of the picked file is deleted after capture, on
     every path.
   - Nothing in the UI claims a location was read.
3. **Settings into capture** (Archie). `PortraitCapture` stays a singleton.
   `capture()` takes optional `placeFinder` / `meetingFinder` overrides, and
   the capture screen builds them from the current settings.
   `MeetingFinder(window:)` becomes a field, and `RememberedCount.threshold`
   becomes a parameter.
4. **Planners** (Archie). `pickNext(…, asked: Set<String>)` returns null when
   nothing is left. Both game call sites are updated, and the turn total is
   fixed at game start.
5. **Reminders default on** (Archie, Sally).
   - Keep `ReminderSettings.off()` for corrupt files. Add `defaults()` (on,
     19:00), used only when nothing has been saved.
   - `sync()` must not switch reminders off for lack of permission while
     nothing has been saved: it just doesn't schedule.
   - `askOnce()` saves the outcome either way, so the user is never asked
     twice. A corrupt file loads as `off`, so it never re-asks.
6. **Settings file** (Sally). `FileSettingsStore.load()` never throws: any
   garbage gives the defaults. It writes temp-then-rename. Tests cover garbage,
   empty, an array and wrong types.
7. **Maps** (Sally, Archie).
   - `StreetMap(streetMaps: bool)` is injected. When it is false, there is no
     tile layer (tests pass false, and one test asserts that no `TileLayer` is
     built).
   - The location picker obeys the same switch.
   - The default stays on, as Eric asked.
   - The disclosure in CLAUDE.md says that the device IP, the user agent and
     the tile coordinates (the area viewed) go to OSM.
   - flutter_map's own HTTP client is used; there is no custom disk cache.
8. **Versions.** Pin `flutter_map`, `latlong2`, `image_picker` and
   `audioplayers` exactly. Check release-build keep rules on a release APK.
