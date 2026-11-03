# Play Store plan, round 2

The Release readiness crew reviewed fix round 1 (see the "Fix round 1"
table in [play-store-plan.md](play-store-plan.md)) on 2026-11-02, in the
uncommitted working tree after 83f544e:
- `owen`, `sally`, `rex`, `tess`, `ada`, `grace` and `lena` reviewed their lanes.
- `fred` walked a release build on the emulator.
- `vera` checked the merged findings against the code.

**Decision:** hold, but close. `fred` found every round-1 fix working in a
release build:
- the consent line, the backup notice, and the camera-off and location-off
  messages;
- readable Teal, Forest and Rust app bars;
- the system contact picker with no permission prompt;
- people surviving a force-stop.

There are no new Blockers in code. The only Blocker is the privacy policy
not yet being online.

`vera` checked the code claims only. She did not check the
policy, product and accessibility items (`grace`, `ada`, `lena` and `fred`'s
notes) against code; they are listed as their authors gave them.

## Fix round 2 (2026-11-03)

Every Should-fix below is now addressed. Core 195 tests, app 235 tests, and
both integration tests on the emulator pass.

**Gate crew** (`hal`, `tess`, `rex`, `sally`, `archie`, `ada`, `daphne`,
`grace`, `lena` → `vera`):
- `vera` confirmed two Should-fixes, both wording on the site, and both now fixed:
  - Delete now removes a person from the phone, but a backup copy may stay.
  - "No analytics" became "none of our own", and the policy names ML Kit and Android diagnostics.
- Considers fixed:
  - a game turn stuck when the screen reader is turned off mid-reveal;
  - Delete now popping a page opened over it;
  - a stale "no location" message after a camera shot;
  - the dictation comment;
  - `hasUploadKey` checking that the key file exists;
  - the site header's unnamed link.
- Considers accepted:
  - no unit test of `DeviceDictation`'s error mapping, or of Delete now's failure branches;
  - the map credit's tap target;
  - a group photo has no Delete now;
  - whether the tile area counts as precise location (`lena` or a lawyer).
- Refuted: Delete now never purging (`daphne`).

| # | What was done |
| --- | --- |
| R1 | The policy moved to [site/privacy.html](../../site/privacy.html), on a new GitHub Pages site (`site/`, published by `.github/workflows/pages.yml`). About links to `https://nebosite.github.io/rememberem/privacy.html`. Live once Eric turns on Pages (Settings > Pages > Source: GitHub Actions) and pushes. |
| R2 | A release build without `key.properties` stops with "No upload key". `-PallowDebugSigning=true` signs with the debug key on purpose, for your own devices. All three cases were built and checked. |
| R3 | `Dictation.listen` takes `onNoSpeechPack`. `DeviceDictation` calls it on `error_language_not_supported` or `error_language_unavailable`, and the field says to download offline speech or type. The app adds no cloud fallback of its own. Without an on-device recogniser, the plugin itself falls back to the phone's default (possibly cloud) recogniser, as the policy says. |
| R4 | `MemoryRepository.unreadable` names the files the last load skipped. The list shows "1 record couldn't be read. It is kept on this phone, untouched." and logs the file names. |
| R5 | The camera screen has its own `ScaffoldMessenger`, so Try again and the location-off message close with it. The "no location came with this photo" message still goes to the app's messenger, after the next screen is up. |
| R6 | `SimpleAttributionWidget` keeps "OpenStreetMap contributors" in view, and tapping it opens openstreetmap.org/copyright. |
| R7 | The policy and About give rememberem@niftibits.com for privacy questions. |
| R8 | The Data safety draft in [play-store-plan.md](play-store-plan.md) (4.3) now declares the map tiles as shared approximate location, encrypted in transit. |
| R9 | The face picker already had a consent line. The group screen now has one too, and a gallery import gets one through R10. "All" is kept, since Eric asked for it. |
| R10 | Right after a photo, the person's page says "Only keep people who are happy to be remembered." and offers **Delete now**: it asks, then deletes for good, not to the trash. Group captures don't get it; their people use the trash. |
| R11 | About and the policy: "The people you photograph are in that backup too. If someone asks where their photo is kept, tell them." |
| R12 | With a screen reader on, both games wait for **Show names** / **Show people** instead of the 3 s timer. The face game shows "Right: …" / "Not …" as visible text, in a live region. |
| R13 | The Faces button reads "Practice faces. Needs sight; Practice details works with a screen reader." |
| R14 | The quality tests compare the saved JPEG's quantisation tables with quality 75, as a literal (mutation-checked: 90 fails two tests). Added cases for a 4000×3000 photo (to 1000×750) and an 800×600 photo (kept as is). |

## Blocker (Eric)

| # | What | Fix |
| --- | --- | --- |
| R1 | The privacy policy URL that About links to (`ericjorgensen.com/rememberem/privacy.html`) shows a generic page (`lena`). | Upload `docs/store/privacy-policy.html` there, then check it loads. |

## Should fix (confirmed by `vera`)

| # | What | Evidence | Fix |
| --- | --- | --- | --- |
| R2 | A release build silently falls back to the debug key. A friend's sideloaded debug-signed build can never be updated by a Play build, so they would have to uninstall and lose their people (`owen`, `sally`). | `build.gradle.kts:55-56` | Fail the release build without `key.properties`, unless an opt-in property is set (for emulator walks). |
| R3 | If the on-device recogniser lacks the language pack, the mic starts and stops with no words and no message (`rex`). | `device_dictation.dart:29-39`, `onError` only calls `_finish()` | Treat a language error as unavailable: return false, or show "Download the offline speech pack in Settings, or type". Eric decides whether to fall back to the cloud recogniser. |
| R4 | A record that can't be read vanishes with no trace, and the UI can't reach it (`rex`, `tess`). | `json_file_memory_repository.dart:291` | Log the file name, count skipped files, and show one line ("1 record couldn't be read") in the list or About. |
| R5 | The Try again snackbar lives on the app's messenger. After leaving the camera, its tap does nothing, and backing out or a kill loses the photo (`rex`). The location-off message shares the cause and can appear over the next screen. | `capture_screen.dart:229-240`, `104-108` | Give the camera screen its own `ScaffoldMessenger`, or hide its snackbars in `dispose`. Optionally keep the bytes in a cache file until saved. |
| R6 | The OpenStreetMap attribution has no link to openstreetmap.org/copyright (`lena`). | `street_map.dart:102-103` | Make it a tappable `TextSourceAttribution` that opens the copyright page. |

## Should fix (not verified against code; policy, wording, access)

| # | What | Fix |
| --- | --- | --- |
| R7 | The privacy policy offers only GitHub issues, which are public, for privacy requests (`lena`). | Add a monitored email address, the same as the Play developer contact. |
| R8 | The draft Data safety answers say "collects and shares no data" and "not encrypted in transit". Map tiles send the IP address and area to OpenStreetMap over HTTPS (`lena`). | Declare what tiles share, answer "encrypted in transit: yes", and have `lena` or a lawyer check the Console's wording. |
| R9 | The consent cue appears only on the live camera. Gallery imports and the face picker have none, and "All" can add a whole crowd in two taps (`grace`). | Add "Only add people who are fine with it" to the face picker and group screens. Consider dropping "All", or making it less prominent. Eric asked for "All", so this is his call. |
| R10 | Nothing helps when the person says no after the photo (`grace`). | On a person just captured, offer "Delete now" (straight to purge, not the trash). |
| R11 | The backup disclosure speaks to the user's interest, not the photographed person's (`grace`). | Add to About and the policy: "Their photo and notes may be copied to your Google backup. Tell them if they ask." |
| R12 | The timed reveal (3 s) can cut TalkBack off mid-prompt. In the face game, "Right/Not" sits on a zero-size node that may never be read (`ada`). | When `accessibleNavigation` is on, skip the timed reveal. Use visible status text in the face game, as the detail game does. |
| R13 | The face game says it needs sight only once you are inside it (`ada`). | Say so on the practice entry, with a pointer to Practice details. |
| R14 | Tests miss two regressions: `keptQuality` 75 to 90 passes (mutation-checked), and the landscape and small-image shrink paths are untested (`tess`). | Compare against `keptQuality + 15`; add 4000×3000 and 800×600 cases. |

## Consider

- **Backup quota:** past 25 MB, Auto Backup silently stops, and "roughly 200 people" is unmeasured (`owen`, `sally`). Measure a typical photo on the phone in a release build (`pamala`) and correct the number. A manual "export people" zip would cover both the quota and backup-off users.
- **Legacy formats:** add frozen legacy-format JSON fixtures, one per old shape, and a `bmgr` backup-and-restore drill in release-steps (`owen`).
- **Reminders after restore:** a restored reminder turns itself off on a new phone without saying so (`owen`).
- **Location wait:** capture can wait up to about 8 s for a location if the shot is taken right away (`rex`). Cap the wait after the shot at about 1 s.
- **Camera permission:** after granting the camera in Settings, coming back doesn't reopen the camera (`rex`). With the camera off, the shutter stays enabled and does nothing (`fred`). There is also an ~8 s bare spinner before the camera prompt (`fred`).
- **Telemetry:** "No analytics" is unverified against ML Kit and Play services telemetry. A traffic capture on a device would settle it (`sally`).
- **Leftovers and logs:** the raw shot is left in the cache if reading it fails; add a `finally`. `debugPrint` of errors reaches logcat in release (`sally`).
- **Test portrait:** the NASA test portrait still ships in release assets (`lena`).
- **Map tiles at scale:** OSM's tile policy doesn't suit production scale; plan a tile provider before the public release (`lena`).
- **Licences:** check ML Kit's notices on the licences page. "Licences" (the row) vs "Licenses" (Flutter's page title) (`lena`, `fred`).
- **Children and notes:** the policy wording on children and sensitive notes is weak (`grace`). The shared group note should say it is added to each person (`grace`).
- **Small targets:** the gallery button is 40 dp. The no-camera buttons may collide with the shutter at 200 % text (`ada`).
- **Place hint:** the Place field's lowercase "unknown" hint looks like real text (`fred`).
- **Integration test:** it captures from the gallery, not the camera (`tess`). The plan's round-1 table should say "gallery capture".

## Still owed before any release

- `lena`'s view on BIPA.
- Eric's upload key ([release-steps.md](../release-steps.md)).
- Integration tests on the phone.
- A release walk on the phone: real face, dictation, a reminder firing.
- iOS is not in scope.

## Suggested order

1. R1, R7, R8: the policy goes online with an email address, and the Data safety form is filled in to match.
2. R2 to R6: small code fixes, one story.
3. R9 to R13: one consent and access story, through Plan check (Eric decides on "All").
4. R14 and the Considers as they fit.
5. Phone walk, Release readiness again, then the closed test.
