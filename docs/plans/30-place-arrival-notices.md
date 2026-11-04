# Story 30: place notices (arrival alerts)

## What Eric asked

- "I don't see an on/off switch for place tag notices." Asked what that
  should be, Eric chose arrival alerts: when the phone arrives at a known
  place, a notice says who he has met there.
- A debug button on About shows a place notice for a chosen place
  (deferred here from story 29).

## What it costs, which Eric should know

- **Background location.** Android's ACCESS_BACKGROUND_LOCATION ("Allow
  all the time") and iOS "Always". The feature is off by default. Nothing
  watches location until Fred turns it on.
- **Google Play.**
  - Once the manifest declares ACCESS_BACKGROUND_LOCATION, every release
    needs a Play Console location declaration, a short video of the
    feature, and a prominent in-app disclosure shown before the system
    prompt. Play prefers foreground-only use, and may reject an app that
    does not show the feature is core.
  - Eric deploys, so this is his to file. The disclosure screen is built
    here.
- **Battery.** The phone's own geofencing (Android GeofencingClient, iOS
  CLLocationManager region monitoring) is cheap. No GPS polling, no
  network, no server.
- **iOS** cannot be built or tried here (no Mac). The plist strings and
  AppDelegate registration are written but not verified.

## Design

### Plugin

- `native_geofence` ^1.5.1 (Flutter 3.44+; Android API 23+; iOS 14+).
- Android manifest:
  - its broadcast receiver, reboot receiver, and foreground service
    (`foregroundServiceType="location"`);
  - ACCESS_BACKGROUND_LOCATION, FOREGROUND_SERVICE,
    FOREGROUND_SERVICE_LOCATION and WAKE_LOCK.
    RECEIVE_BOOT_COMPLETED is already there.
- iOS:
  - Info.plist gets NSLocationAlwaysAndWhenInUseUsageDescription.
  - AppDelegate calls `NativeGeofencePlugin.setPluginRegistrantCallback`.
  - The minimum iOS rises from 15.5, so it is already ≥ 14.
- Behind a small interface, `PlaceFences`, with
  `sync(List<PlaceFence>)` and `clear()`, so the app and tests do not
  touch the plugin.

### Core (pure Dart)

- `PlaceNotice`:
  - `fenceId(place)` ("place:" plus the trimmed name) and `placeOf(id)`;
  - `wireId(place)` and `placeFromWire(payload)` for the tap;
  - `textFor(active, place)`: "You've met Ann Lee, Bo and 2 more here."
    With no one, it says nothing (no notice);
  - the title is the place's name, "At Cafe";
  - `due(lastShown, now)`: once per place per 12 hours, so a
    regular haunt never nags.
- `PlaceFence(id, at, meters)`: the fences to keep. They are the named
  places with a location (with moved spots), at least 100 m (geofences
  are unreliable smaller), at most 90, newest first (Android allows 100
  per app, iOS 20). On iOS the plugin's own cap applies, so the 18
  newest.

### App

- **Setting.** `ReminderSettings.places` (bool; missing reads false) in
  reminders.json, beside the anniversary switch.
- **Settings > Reminders.** A "Place notices" switch: "When you arrive
  somewhere you have met people, a note says who. Uses your location in
  the background; it stays on this phone."
- **Turning it on** opens `PlaceNoticeConsent`, a full-screen page and the
  prominent disclosure:
  - **What:** "Rememberem uses your location in the background, even when
    the app is closed or not in use, to notice when you arrive at a place
    where you have met people."
  - **Where it stays:** "Your location is never sent anywhere."
  - **How:** "On the next screen choose 'Allow all the time'."
  - Then the location permission is asked (geolocator), and if needed the
    app's settings open for "Allow all the time".
  - On return, if "always" was granted, it turns on. Otherwise it stays
    off, saying why. It is never asked twice unasked.
- **`PlaceNoticeKeeper`.** It syncs on every app open, on resume, after a
  place is renamed, moved or resized, and on the list's return.
  - On, with "always": it registers the fences.
  - Off, or the permission was taken away: it clears them, and turns the
    switch off if the permission went.
- **The fence callback.** A top-level `@pragma('vm:entry-point')`
  function, run by the plugin in a background isolate. It:
  1. opens the repository at getApplicationDocumentsDirectory()/memories;
  2. reads settings.json and reminders.json, and stops if place notices
     are off;
  3. reads `place_notices.json` (when each place last showed) and stops
     if not due;
  4. reads the active people met there and builds the text;
  5. shows a notification on channel `places_named` (secret on a locked
     phone, big text), with payload `place:<name>`;
  6. records the time.

  The trigger is a dwell of 3 minutes on Android (no drive-bys), and
  entry on iOS. Errors log only their type.
- **A tap** opens the list filtered to that place (`PlaceFilter`), as an
  anniversary notice does: never over the camera or a game.
- **Debug.** "Place notice for…" picks a named place and shows its
  notice now (id 902).

### Privacy

- The location never leaves the phone. Fences are registered with the
  OS's own geofencing; Google Play services on Android does the
  monitoring, as it does for any geofence. The cooldown file holds only
  place names and times.
- `place_notices.json` and the plugin's stores are excluded from backup:
  - `native_geofence` keeps its fences in its own prefs; the file name is
    to be checked in the plugin source;
  - notification text goes to `scheduled_notifications.xml`, already
    excluded. These notices are shown, not scheduled.
- Updates to the policy, About and CLAUDE.md:
  - background location, opt-in and off by default;
  - on the phone only;
  - the lock screen;
  - a watch may show them.

## Tests

- **Core:**
  - fence ids and payloads round-trip; junk is refused;
  - the text;
  - the 12-hour rule;
  - fence selection: named and located only, moved spots, a 100 m floor,
    the cap, newest first.
- **App:**
  - the switch is off by default;
  - turning it on shows the disclosure before any permission request;
  - denied stays off; granted turns on and syncs fences (with a fake
    `PlaceFences`);
  - off clears them;
  - a place payload opens the filtered list;
  - the callback's work in a testable class (`PlaceArrival.handle(place,
    now)`) with a fake repository and notifier: shown once, not again
    within 12 h, not when off, not for a place with no one;
  - the debug button.
- **Device:** a fred walk on the emulator, with the location set by
  `adb emu geo fix`: enter a fence and see a notice.

## As built (after Plan check and Gate; supersedes the design above)

- **No foreground service** (lena, sally). Only ACCESS_BACKGROUND_LOCATION
  is added. WAKE_LOCK and plain FOREGROUND_SERVICE come from WorkManager,
  with no location-typed service, so there is no foreground-service
  declaration. The plugin's receivers are not exported.
- **Opaque ids** (sally). A fence's id is `PlaceNotice.fenceId`, an FNV
  hash of the trimmed name (case kept). It is used in the plugin's store,
  its logs, `place_notices.json` and the tap payload `arrival:f<hash>`;
  the callback finds the place by hashing the known names.
- **Backup exclusions.** `native_geofence_plugin_cache.xml` (sharedpref)
  and `app_flutter/place_notices.json` (root) are excluded, alongside
  `scheduled_notifications.xml`.
- **Permission flow** (hal). geolocator 14 crashes when only the
  background permission is asked a second time. With "while in use", the
  app's settings page opens instead (`LocationAsk.inSettings`); on
  resume the keeper turns notices on if "all the time" was chosen.
  Notifications are asked first; refused, location is never asked.
- **Robustness** (rex, tess, hal).
  - Keeper calls run one at a time.
  - Each fence is tried on its own, and every sync re-adds every wanted
    fence (fences the phone dropped come back).
  - A failed plugin set-up is retried next time.
  - iOS watches at most 18.
  - Turning on when no fence can be added leaves it off.
  - A permission check that cannot answer changes nothing.
  - A notice that could not show leaves the place due.
  - The cooldown file uses unique temp names.
- **Debug.** "Place notice for…" shows the chosen place's text at once
  (id 902), through the keeper. It does not run the background path.
- **Release builds.** A keep rule for `com.chunkytofustudios.native_geofence`.
  The release APK builds; an arrival in a release build is not yet walked.

