# Story 21: Place notifications

## Goal
When Fred arrives at a place where he has met people, the phone tells him,
and tapping the notice opens the list filtered to that place, so he can
refresh the names before he walks in. Off by default. Fred can silence any
place, and places named "home", "work" or "church" start silenced.

## Acceptance criteria
1. Settings has a **Place notifications** switch, off by default. With it
   off, no fence is registered and no location or notification permission
   is asked.
2. Turning it on first shows a short in-app explanation (what is watched,
   that it stays on the phone, that Android will ask for location "all the
   time"), then asks for notifications, location, and background location
   in turn. If any is refused the switch stays off and the section says
   what is missing, with a button to the app's system settings.
3. Below the switch, a collapsible **Places** list shows every named place
   with a checkbox. Checked means notifications for that place are not
   disabled. Changing a box applies at once.
4. The Places page's rename/name dialog has a **Notify me when I arrive
   here** checkbox. It starts at the place's current choice. Until Fred
   touches it, it follows the default for the name being typed. Saving
   stores the choice under the new name.
5. A place with no stored choice is on, unless its trimmed name matches
   `home`, `work` or `church`, ignoring case. Those are off until Fred
   turns them on.
6. While the switch is on and permissions are held, one geofence is
   registered for each named place that has a location and is not
   silenced. The fence is centred on the place's newest located encounter,
   with a radius of `max(place radius setting, 150 m)`. There are at most
   100 fences (Android's limit), keeping the most recently visited places.
   Trashed people do not count.
7. A notice fires on **dwell** (about 5 minutes inside), not on a drive-by.
   The same place notifies at most once every 12 hours.
8. The notice says `You're at <place>` / `See who you've met here`. It
   never names a person. Lock-screen visibility is private, with a generic
   public version (`Rememberem` / `You're at a place you know`).
9. Tapping the notice, cold or warm, opens the Filter List with a Place
   filter for that place, over the list (via `_openOnRoot`). Back returns
   to the list. A tap while the camera is open is ignored. An empty,
   unknown or forged place name simply shows the filter (no one matches)
   and never throws.
10. Fences are re-registered on every app open and resume, after a
    settings change to place notifications, after a rename, and after a
    reboot or app update (native boot receiver, from the last list the app
    gave). If permission was revoked, sync turns the switch off and clears
    the fences.
11. Renaming a place carries its choice to the new name. Renaming into an
    existing place gives the merged place the dialog's checkbox value.
12. Android only for now. On iOS the switch, the list, and the dialog
    checkbox are hidden (the coordinator is null, as contacts are).
13. No network calls are added. The fence list and the per-place cooldown
    are kept in app-private storage only.

## Design

### Core (`packages/rememberem_core/lib/src/`)
- `AppSettings` gains `placeAlerts` (bool, default false) and
  `placeAlertChoices` (`Map<String, bool>`, keyed by trimmed place name,
  default empty). Both are tolerant in `fromJson`: a non-bool value is
  dropped, and a non-map value gives empty. They are added to `copyWith`,
  `toJson`, `==` and `hashCode`. Adding keys needs no migration.
  - `bool alertsFor(String place)`: `placeAlertChoices[trimmed] ??
    !PlaceAlertDefaults.quiet(trimmed)`.
  - `AppSettings withPlaceAlert(String place, bool on)` and
    `AppSettings renamePlaceAlert(String from, String to, bool on)`, which
    drops `from` and sets `to`.
- `place_alert_defaults.dart`: `PlaceAlertDefaults.quiet(name)` checks
  case-insensitive, trimmed `{home, work, church}`.
- `place_fence.dart`: value class `PlaceFence {name, center, radiusMeters}`
  with `toJson` (used by the platform channel).
- `place_fence_planner.dart`: `PlaceFencePlanner.plan(List<Memory> active,
  AppSettings settings)` returns `List<PlaceFence>`. It returns empty when
  `!settings.placeAlerts`. Otherwise it takes the named groups from
  `PlaceBook.from(active)` that have a `marker` and `alertsFor(name)`,
  sorts them by newest, keeps the first 100, and sets the radius to
  `max(settings.placeFinder.radiusMeters, 150)`.
- Export the new files from `rememberem_core.dart`.

### App (`app/lib/src/place_alerts/`, one class per file)
- `place_fencer.dart`: abstract interface `PlaceFencer`:
  `Future<PlaceAlertAccess> access()`, `Future<PlaceAlertAccess>
  requestAccess()`, `Future<void> replace(List<PlaceFence>)`,
  `Future<String?> launchPlace()` (given once), `Stream<String> taps`, and
  `Future<void> openSettings()`.
- `place_alert_access.dart`: `enum PlaceAlertAccess { granted,
  notifications, location, background }`. Each non-granted value names
  the first missing permission.
- `android_place_fencer.dart`: `MethodChannel('rememberem/place_fences')`.
  Every call is in try/catch. Errors give `replace` a no-op and give
  `access` the value `location`.
- `place_alert_coordinator.dart`: owns the `PlaceFencer`, the
  `AppSettingsController` and the `MemoryRepository`. Every operation runs
  through one serial chain, as `ReminderCoordinator` does.
  - `sync()`: when off, replace with `[]`. When on but `access()` is not
    granted, turn the setting off and replace with `[]`. Otherwise read
    `repository.all()` (on a throw, leave the fences as they are),
    re-read the settings, plan, and replace.
  - `setEnabled(bool)` returns `PlaceAlertAccess`. Turning on calls
    `requestAccess()`. If not granted it stays off and returns the missing
    one; if granted it saves on and syncs.
  - `setPlace(name, on)` saves the choice and syncs.
  - `renamed(from, to, on)` moves the choice and syncs.
  - `places()` returns the distinct named places for the settings list,
    from `MemoryFilter.places(await repository.all())`.
- `place_alerts_section.dart`: the Settings section. It has the switch;
  when on, an `ExpansionTile` titled "Places" with a `CheckboxListTile`
  for each place. It also shows the missing-permission text with an
  "Open settings" button, and the explanation dialog shown before the
  first request.
- `AppServices` gains `PlaceAlertCoordinator? placeAlerts` (null on iOS and
  in tests). `main.dart` builds it on Android. It syncs after the first
  frame and on resume, and also when `settings` changes in a way that
  touches `placeAlerts`, `placeAlertChoices` or `placeRadiusFeet` (a
  listener that compares those fields).
- `SettingsScreen` gets `placeAlerts` and shows the section under a
  "Place notifications" heading.
- `RenamePlaceDialog` gains a `notify` initial value and a
  `followDefault` flag. `show` returns `({String name, bool notify})?`.
  The checkbox is shown only when `PlacesScreen` has a coordinator. In
  `PlacesScreen._rename`, an unchanged name skips the renamer and only
  saves the choice. Then it calls `coordinator.renamed(old ?? new, new,
  notify)`.
- Routing (`rememberem_app.dart`): after the first frame, subscribe to
  `placeAlerts.fencer.taps` first, then route `await launchPlace()`.
  `_openPlaceAlert(String? place)` ignores null or blank, trims the name,
  caps it at 200 characters, and calls `_openOnRoot(AppRoutes.placeAlert,
  FilterListScreen(initialFilters: [PlaceFilter(name)]), blockedBy:
  {capture})`. It is wrapped in try/catch. `AppRoutes.placeAlert` is new.

### Android (`app/android/app/src/main/kotlin/.../`)
- `build.gradle.kts`: add `implementation("com.google.android.gms:
  play-services-location:21.2.0")`. This is the same artifact and version
  geolocator already ships, so no new library enters the APK.
- Manifest: add `ACCESS_BACKGROUND_LOCATION`. Add the receivers
  `PlaceFenceReceiver` and `PlaceFenceBootReceiver`, both
  `exported="false"`. The boot receiver handles `BOOT_COMPLETED` and
  `MY_PACKAGE_REPLACED`; `RECEIVE_BOOT_COMPLETED` is already declared.
- `PlaceFences.kt`, the channel handler:
  - `access` checks POST_NOTIFICATIONS on API 33+, FINE location, and
    BACKGROUND location on API 29+.
  - `requestAccess` asks for each missing permission in turn through
    `ActivityCompat.requestPermissions` (results arrive through
    `MainActivity.onRequestPermissionsResult`). Background is asked last,
    alone.
  - `replace(list)` saves the list as JSON in private SharedPreferences
    `place_fences`, then calls `GeofencingClient.removeGeofences(pi)` and
    `addGeofences` with DWELL transitions, a 5-minute loitering delay and
    no expiry. An empty list only removes.
  - `launchPlace` reads the activity's launch intent extra. `onNewIntent`
    pushes `tap` to Dart.
  - `openSettings` opens the app's details settings.
- `PlaceFenceRegistrar.kt`: shared code that registers the saved list.
  The channel and the boot receiver both use it. It holds the PendingIntent
  (`FLAG_MUTABLE`, needed on API 31+ for geofence extras).
- `PlaceFenceReceiver.kt`: on a DWELL event, for each triggering fence id
  (the place name), it skips the place if it was notified less than 12
  hours ago (time kept in `place_fences` prefs). Otherwise it posts the
  notice on channel `places`, private, with the generic public version,
  `setAutoCancel`, tag = place, and a content intent opening `MainActivity`
  with action `com.rememberem.rememberem.PLACE` and extra `place`
  (`FLAG_IMMUTABLE`). It uses the platform `Notification.Builder`, so no
  new androidx dependency.
- `PlaceFenceBootReceiver.kt`: re-registers the saved list if location
  permission is still held.
- `MainActivity`: create the channel handler, route permission results
  and `onNewIntent` to it.
- `proguard-rules.pro`: the GMS location API is public and kept by its
  consumer rules. Verify with a release build.

## Tests
- Core `app_settings_test`: defaults (off, empty), round trip, a bad
  choices shape gives empty, non-bool entries are dropped, `alertsFor` for
  home, Home and " WORK " is false and for Cafe is true, an explicit
  choice overrides the default, `renamePlaceAlert` moves the key.
- Core `place_fence_planner_test`: off gives empty; unnamed places and
  places without location are skipped; silenced places are skipped;
  quiet defaults are skipped unless chosen on; the cap of 100 keeps the
  newest; the radius has a 150 m floor; the centre is the newest located
  encounter.
- App `place_alerts_test` (fake fencer):
  - Coordinator: sync with the switch off replaces with an empty list;
    enabling with denied access stays off and returns the missing
    permission; enabling with access saves on and registers fences;
    revoked access on sync turns the switch off; a repository throw
    leaves the fences alone; `renamed` moves the choice.
  - Settings section: the switch is off by default; the places list shows
    names with home unchecked; toggling a box updates the settings.
  - Rename dialog: the checkbox starts from the current choice; typing
    "Home" unchecks it while untouched; once touched it no longer follows.
  - Routing: a launch place opens the Filter List with that place filter;
    back lands on the list; a warm tap does the same; a tap over capture
    is ignored; a blank tap does nothing.

## Risks
- **Play policy:** `ACCESS_BACKGROUND_LOCATION` needs a Permissions
  Declaration and a video, and Google may refuse it. This blocks a store
  release, not a check-in. Eric decides before release.
- **Privacy:** Google Play services evaluates the fences on the device.
  Location stays with the phone's location provider, as it already does
  for capture through the fused provider. The fence list holds place
  names and coordinates in `shared_prefs`, which are in Android backup
  (risk 6), next to `memories/`, which already holds the same data. The
  About page, the privacy policy, and the Data safety form must mention
  background location before release.
- **Battery:** geofencing is low power, and DWELL with a 5-minute delay
  cuts down on wakeups.
- **Delivery:** fences are dropped when location is turned off or app data
  is cleared. The app re-registers them on open.
- **Untested on a device:** the native code. It cannot be verified until
  Eric runs it on a phone.

## Out of scope
iOS (`CLLocationManager` region monitoring). Naming people in the notice.
Per-place quiet hours. Choosing the dwell time.

## Amendments (settled in review; these override the design above)
1. **No settings listener.** `setEnabled`, `setPlace` and `renamed` save and
   then sync once, inside the coordinator's serial chain. The radius
   stepper takes effect on the next open or resume. This removes the
   listener race (rex 5) and the double syncs (archie 1).
2. **Background location (rex 1, owen 2).** API 29 shows a dialog. On API
   30+ the request goes to the system Settings page, so the result is not
   trusted. `requestAccess` returns what `access()` reports afterwards. The
   coordinator remembers the pending wish in memory (`_wanted`), and the
   next `sync()` on resume turns the switch on if access is then granted.
   Approximate-only location counts as `location` (not granted).
3. **Permission results (rex 2, archie).** The fencer uses its own request
   codes (4811-4813), keeps a single pending result, and completes an
   earlier pending result when a new request starts.
4. **Launch extra consumed (rex 3, archie 4).** `launchPlace` reads the
   extra and removes it. `onNewIntent` calls `super` (for `quick_actions`)
   and then forwards `tap`.
5. **Routing (rex 4).** `blockedBy: {capture, practice}`, as reminders
   use. The place subscription is cancelled in `dispose`. A place tap over
   an open filter replaces it, because `_openOnRoot` pops to the list
   first. A tap over the notes screen relies on the dispose flush
   (precedent: story 14).
6. **Fence ids (owen, archie 8).** The request id is the index in the saved
   list, and the receiver maps it back to the name. Explicit-component
   intents (sally 4, owen): the geofence PendingIntent uses
   `FLAG_UPDATE_CURRENT | FLAG_MUTABLE` with
   `Intent(ctx, PlaceFenceReceiver::class.java)`. The notice content
   intent uses `FLAG_IMMUTABLE` and the package's own launch intent
   (`setPackage`), as `flutter_local_notifications` does (changed at the
   Gate; see below).
7. **Failure is shown (rex 6, owen).** `replace` returns false on failure
   (no Play services, location off, GEOFENCE_NOT_AVAILABLE). The
   coordinator exposes `unavailable`, and the section says "Your phone
   can't watch places right now. Check that location is on."
8. **Receiver and boot (owen, archie 5-6, rex 7).** The receiver creates
   the `places` channel itself (API 26+ guard), checks POST_NOTIFICATIONS,
   and uses `R.mipmap.ic_launcher`. The boot receiver re-registers only if
   the saved list is non-empty, it parses, and the location and background
   permissions are held. Otherwise it does nothing.
9. **Privacy (sally 1, 2, 5, 6).** `setLocalOnly(true)` keeps notices off
   wearables. The public version carries no name. `place_fences.xml` is
   excluded from backup through `fullBackupContent` and
   `dataExtractionRules` (memories backup unchanged). The explanation
   dialog says Android's location service on the phone checks the places,
   that Rememberem sends nothing, that the notice shows the place name
   when the phone is unlocked, and that location is used even while the
   app is closed. No logging of names or coordinates.
10. **Rename (archie 2, tess 2).** `renamed` is called only after
    `PlaceRenamer.rename` succeeds. An unchanged name skips the renamer.
    Choice keys are exact trimmed names, case-sensitive like `samePlace`.
    The quiet defaults ignore case.
11. **Settings list (archie 7).** It lists only named places that have a
    located encounter (`PlaceBook`), because a place without a location
    can never notify. `places()` is dropped from the coordinator.
12. **Tests added (tess).** A method-channel contract test for
    `AndroidPlaceFencer`; rename-into-existing; a rename failure leaves
    choices alone; an unchanged-name toggle does not call the renamer;
    trashed people are not fenced; a tie order is deterministic; a
    revoked sync asserts both off and `replace([])`; place and reminder
    launch on the same first frame; a tap over a game is ignored; a
    whitespace name is trimmed.
13. **Disclosures (sally).** About, `site/privacy.html` and the CLAUDE.md
    privacy list are updated in this story. The Data safety form and the
    Play background-location declaration are left to Eric before release.

## Review record
Planning crew (slimmed, as Eric asked): builders `archie` and `owen`;
guardians `tess`, `sally` and `rex`. All objections were accepted or
mitigated as above, so nothing was left disputed for `vera` and no
TieBreaker was needed.

Unverified:
- How background-location requests behave on API 30+.
- Whether Play's consumer proguard rules keep geofencing in a release
  build.
- Reboot re-registration.

All three need a device.

## Gate review (check-in)
Crew: `hal`, `tess`, `rex` and `sally`, then `vera`. Fixed:
- **Process death:** a notice tap is not replayed when the app is reopened
  from Recents (`FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`, the same check
  `flutter_local_notifications` uses).
- **Resume refresh:** the "can't watch places" line refreshes on resume. The
  section waits for the app's sync (`settled()`) instead of running its
  own.
- **Retry and save order:** a failed add is retried once. The new list is
  saved only after the old fences are removed, so a fence index never
  resolves against the wrong list.
- **Check errors:** an `access()` channel error returns null, and sync then
  leaves the setting and the fences alone. It no longer switches the
  feature off.
- **Renaming a silenced place:** the place stays silenced. An untouched box
  shows the place's own explicit choice; otherwise it shows the typed
  name's default.
- **Bad coordinates:** out-of-range coordinates are skipped instead of
  failing the whole list.
- **Wording:** the lock-screen text now says "with a screen lock set".

Rebutted (hal): the notice's tap intent stays the package launch intent,
as `flutter_local_notifications` builds it for reminders, whose warm taps
already reach `onNewIntent` in this app. Amendment 6's "explicit
`MainActivity` component" is replaced by this.

Known limits (accepted):
- A place added by a capture is watched from the next open or resume.
- Every sync re-registers all fences. A visit already in progress when
  the app opens (inside the fence, with the dwell timer running) gives no
  notice, because the initial trigger is off.
- A tap while the camera or a game is open is dropped, and the notice is
  gone.
- `_wanted` lives for the process. Allowing "all the time" later from the
  phone's Settings turns the switch on at the next resume.
