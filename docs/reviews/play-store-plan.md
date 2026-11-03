# Play Store plan

What must happen before Rememberem can go on the Google Play Store. This
comes from the Feature ship check crew at commit 83f544e (2026-11-02):
`fred` walked a release build on the emulator, `tess`, `rex`, `daphne`,
`ada` and `pamala` each reviewed their lane, and `vera` checked the merged
findings. The Money pass on this plan is in
[money-pass.md](money-pass.md).

**Decision:** hold. The app works end to end in a release build, with no
crash and data surviving a restart (`fred`). But Play will not accept the
upload as it is (signing), and four confirmed defects would hurt real
users or contradict the privacy promise. None is large.

## Fix round 1 (2026-11-02)

Every Blocker and Should-fix below is now addressed in code (uncommitted at
the time of writing). Core 192 tests, app 223 tests, and both integration
tests on the emulator pass. Release readiness then reviewed the round; its
findings are in [play-store-round-2.md](play-store-round-2.md).

| # | What was done |
| --- | --- |
| 1 | `build.gradle.kts` signs release builds with the upload key named in `android/key.properties` (git-ignored), and falls back to the debug key without it. A bundle signed with a throwaway key was built and verified. Eric still makes the real key; see [release-steps.md](../release-steps.md). |
| 2 | The camera keeps the photo until it is saved; a failure says "Couldn't save this photo…" with **Try again**, which reuses the same photo. |
| 3 | `_loadAll` skips a record it can't read and leaves the file on disk. No count is kept (nothing would read it yet). |
| 4 | Backup stays **on**, Eric's call (4.1). The manifest says so explicitly; About explains it, including Google's 25 MB-per-app limit, and the empty list mentions it. |
| 5 | Kept photos are shrunk to 1000 px on the long side at JPEG quality 75; the working copy is 95. Not yet measured on the phone. |
| 6 | Avatars and small photos decode at display size (`ResizeImage` / `cacheWidth`). |
| 7 | No camera, or a refused one, says so plainly with **Open settings** and **Choose a photo instead**. Camera, camera.any, autofocus, microphone and location are all `required="false"` (checked with `aapt2 dump badging`). |
| 8 | No exception text reaches the screen; errors go to `debugPrint`. |
| 9 | Detail cards take a screen reader's tap; prompts and answers are live regions ("Not Bo.", "Right: Ann."); the face game's photo says it needs sight. |
| 10 | App-bar text is gold where it reaches 4.5:1, else white; a test checks every theme colour. |
| 11 | One line above the shutter: Ask first: "Mind if I take a photo so I remember your name?" |
| 12 | The empty list names the three permissions; one shared "Allow in Settings" message serves location (now reported when off) and the microphone. |
| 13 | `integration_test/life_cycle_test.dart`: gallery capture with real ML Kit, name, restart, trash, restore. Release steps are written down in [release-steps.md](../release-steps.md). |

Also from Eric's notes in section 4: dictation requests on-device
recognition; contacts use only the system picker and `READ_CONTACTS` is gone;
About links the privacy policy and the licences page; a privacy policy draft
is in [site/privacy.html](../../site/privacy.html) (moved there in round 2).

## 1. Blockers (Play rejects it, or users lose data)

| # | What | Evidence (`vera` confirmed) | Fix |
| --- | --- | --- | --- |
| 1 | The release build is signed with the debug key. | `app/android/app/build.gradle.kts:36-38` | Make an upload keystore (kept out of git), add a release `signingConfig`, enrol in Play App Signing, upload an app bundle (`flutter build appbundle`). |
| 2 | A failure while saving a new photo loses it. The raw shot is deleted before `prepare`/`saveOne` succeed. | `capture_screen.dart:80-82`, then 139, 161 | Keep the bytes until `add` succeeds; on failure offer "Try again" with the same bytes. Test with a repository whose `add` throws. |
| 3 | One unreadable record hides every person (`all()` and `trashed()` throw). | `json_file_memory_repository.dart:281-291` | Skip a bad file in `_loadAll` (the pattern exists at line 148), keep it on disk, and count it for diagnostics. Test with a file holding `{`. |
| 4 | Android backup is on by default, so photos, notes and GPS can go to Google Drive. That contradicts "private by default" and the Data safety form. | No `allowBackup`/`dataExtractionRules` in `AndroidManifest.xml` | Eric's call (see 4.1): `allowBackup="false"`, or exclude `memories/` with `dataExtractionRules` (Android 12+) and `fullBackupContent`. |

## 2. Should fix before strangers use it

| # | What | Evidence | Fix |
| --- | --- | --- | --- |
| 5 | Photos are stored at full resolution, JPEG quality 100 (one photo on Eric's phone is 13 MB). Storage grows by GBs and capture is slower. | `portrait_cropper.dart:23,34`; image 4.12 defaults to 100 | Encode at quality 75 and cap the long side at about 1000 px. Measure file size and shutter-to-notes time in a release build (`pamala`). |
| 6 | List avatars decode full-size photos, so long lists jank or run out of memory on cheap phones. | `memory_tile.dart:44`, `person_chip.dart:23`, `detail_game_screen.dart:311` | `ResizeImage(FileImage(photo), width: 120)` / `cacheWidth`, as `timeline_miniature.dart:39` already does. |
| 7 | No camera (tablets, Chromebooks) leaves the camera screen stuck: `cameras.first` throws a `StateError`, which `on Exception` misses. A denied camera shows raw exception text and no way to Settings. | `capture_screen.dart:55,68-69` | Catch `Object`; say it plainly with "Open settings" and "Choose a photo instead". Add `<uses-feature android:name="android.hardware.camera" android:required="false"/>` so Play does not hide the app from those devices. |
| 8 | Raw exception text reaches users. | `capture_screen.dart:69,174`, `face_picker_screen.dart:87`, `group_details_screen.dart:76` | `daphne`'s rewrites: "Couldn't save this photo. Check that your phone has free space, then try again." Log the error with `debugPrint`. |
| 9 | Practice games don't work with TalkBack: the detail cards drop their tap action, and results are never announced. | `detail_game_screen.dart:291-306` | Add `onTap` to the `Semantics`, use `liveRegion` for the prompt and result, and say in the face game that it needs sight. |
| 10 | The gold app-bar text fails contrast on the Teal (3.7:1), Forest and Rust (2.8:1) themes. | `rememberem_theme.dart:63-65`, `app_palette.dart` | Darken those three colours, or switch to white text when gold falls below 4.5:1. |
| 11 | No consent cue when photographing one person. The group picker asks for only "people who are happy to be remembered"; the single shot says nothing. | `capture_screen.dart` | One quiet line above the shutter: "Ask first: 'Mind if I take a photo so I remember your name?'" No extra step. |
| 12 | Permission prompts arrive bare, mid-meeting (camera, then location, then mic). Revoked location or mic just goes silent. | `capture_screen.dart:50-72`, `device_location.dart:17-19`, `device_dictation.dart:55` | A one-line explanation on the empty list ("Rememberem asks for the camera, the microphone and location. All stay on your phone."), plus one shared "Allow in Settings" message. |
| 13 | Release testing is too thin: one integration test (face cropping), not run in any script. | `app/integration_test/face_cropping_test.dart` | Add one integration test for capture, edit, restart, trash and restore; make "integration tests on emulator and phone" a written release step. |

## 3. Consider (polish, not gating)

- **Small phones.** The list app bar holds a 140 dp logo plus five icons, which crowds a 360 dp screen. Move Places and Trash into a menu with About (`ada`).
- **Merge text.** The Merge label is 8.4 sp at default size. That was Eric's own request (40 % smaller), so it is his call; at large text sizes, stack the photo group under the photo.
- **Small targets.** The colour swatches are 36 dp; the correct-answer green is 3.3:1.
- **Test photo in release.** The NASA test portrait (77 KB) ships in release builds.
- **Empty-list text.** `daphne`'s rewrite teaches the app and the shortcut better.
- **iOS wording.** README says Android and iOS; the first release is Android only.
- **Translation.** Hard-coded English throughout. Fine for a first English-only release.

## 4. Store and policy actions (Eric)

These are not code, and only Eric can do them. Check the Play Console's
current rules, because policy numbers change.

1. **Privacy decisions** (CLAUDE.md "Privacy questions still open"; owned by `sally` and `lena`):
   - Backup on or off (blocker 4).  (Eric says: Off, but suggest turning it on)
   - Speech recognition: `device_dictation.dart` does not ask for on-device recognition, so audio may go to Google. Either request on-device where available, or disclose it. (Eric says: request On-device)
   - Map tiles: OpenStreetMap sees the device IP and the area viewed. Disclose it; Settings can turn it off. (Eric agrees)
   - Contacts: READ_CONTACTS needs Play's permissions declaration, or a switch to the system picker only. (Eric says: Default to system picker)
   - Photo location: ACCESS_MEDIA_LOCATION needs a stated purpose. (Eric says: "To be able to use location as a way to remember faces.  e.g.: Oh, I remember meeting that person at the ball game.")
   - Faces: on-device ML Kit, but storing faces of non-users may fall under biometric laws such as BIPA. Get `lena`'s view, and say plainly in the policy that nothing is used for identification. (Eric says: Yes)

   **How these landed (fix round 1):**
   - Backup: read as **on by default, made clear** (the later note in item 3). The manifest keeps `allowBackup="true"`; About and the empty list say people are in the phone's Google backup and how to leave Rememberem out. There is no in-app switch; turning it off is the phone's backup setting. The first note, "Off, but suggest turning it on", could also mean off by default with a prompt to turn it on. **Eric to confirm.**
   - Speech: `onDevice: true`. On Android 12+ with an on-device recogniser the audio stays on the phone; otherwise the plugin falls back to the phone's service with "prefer offline", which may still use the network. About and the policy say so.
   - Map tiles: disclosed in About and the policy.
   - Contacts: system picker only. `READ_CONTACTS`, the in-app list and the name matcher are removed, so no permissions declaration is needed.
   - Photo location: Eric's purpose is in the policy's Permissions section; use the same words in the Console.
   - Faces: the policy says detection only crops, with no templates or identification. `lena`'s view on BIPA is still owed.
2. **Privacy policy URL.** Required for camera, location, microphone and contacts. Host it on ericjorgensen.com. (Eric says: Yes, write a copy locally that I can move over)
   - Done: [site/privacy.html](../../site/privacy.html). Round 2 moved it onto the project's GitHub Pages site, `https://nebosite.github.io/rememberem/privacy.html`, which About links to. Use the same URL in the Console.
3. **Data safety form.** It must match the decisions above. Today the honest answer is "no data collected or shared" only if speech stays on the device and backup is off; otherwise it must list them.  (Eric says: Backup is on by default.  Make it clear to the user. )
   - Draft answers (corrected in round 2, R8), for `lena` or a lawyer to confirm against the Console's current wording:
     - **Collected by the developer:** none. Nothing reaches the developer.
     - **Shared:** map tiles. With Street maps on (the default), the app asks OpenStreetMap for tiles, which sends the device's IP address and the area shown (approximate location). The map zooms to street level (zoom 16 and closer), so tiles can reveal a block-level area: ask `lena` or a lawyer whether that counts as precise. Declare it rather than argue it away: data type "Approximate location" (and, if the Console asks, "Device or other IDs" for the IP address), shared with a third party, purpose "App functionality", optional because Settings can turn street maps off. Names, photos and notes are never sent.
     - **Not developer collection:** Android Auto Backup is a system service the user controls. Speech fallback goes from the phone's own speech service, not the app.
     - **Encrypted in transit:** yes. Tiles load over HTTPS.
     - **Deletion:** users can delete people in the app (Trash, or Delete now right after a photo); uninstalling deletes everything on the phone. There is no account to delete.
     - **Privacy policy URL:** `https://nebosite.github.io/rememberem/privacy.html`; contact email rememberem@niftibits.com.
4. **Developer account and testing track.** A new personal developer account must run a closed test with a minimum number of testers for a minimum period before production access. At the time of writing that was 12 testers for 14 days; confirm in the Console. This is also the natural first marketing step (see the Money pass).
5. **Target API level.** targetSdk 36 (Flutter's default) meets the current requirement. Recheck at upload, since Play raises it every year.
6. **Content rating questionnaire, app category** (Productivity, or Lifestyle), and **ads declaration** (no ads). (Eric says: Productivity)
   - Category: **Productivity**.
7. **Store listing assets.** A 512 px icon (from `app/assets/branding/`), a 1024×500 feature graphic, and phone screenshots of the list, capture, a person page and practice, all using test people, never real records.
8. **Store text.** `daphne`'s draft, held until item 1 settles whether "stays on your phone" is fully true:
   - Short (78 chars): "Remember the people you meet: a quick photo, their name, and what matters."
   - Full: "Meeting someone new? Remember'em helps you remember their name, face, and what makes them special. Tap Meet someone for a quick photo, cropped to head and shoulders. Speak or type their name, where you met, and anything worth remembering; it saves as you go. Practice reminders lead you to flash card quizzes to help the names stick. Your photos and notes stay on your phone, if you want, in private app storage: no account, no ads, no uploads. Please ask before you photograph someone."
   - Updated for backup on: replace the second-last sentence with "Your photos and notes are kept in private storage on your phone, and in your phone's Google backup if that is on. No account, no ads, no analytics." Drop "no uploads", which backup and speech fallback make untrue.

## 5. Release steps still owed (CLAUDE.md)

Before any build reaches someone else, CLAUDE.md requires the
**Release readiness** crew (`owen`, `sally`, `rex`, `tess`, `fred`, `ada`,
`grace`, `lena` → `vera`), integration tests on an emulator **and** the
phone, and `fred` walking the story on the phone, including face
detection and a reminder firing in a **release** build. This ship check
did not cover:

- face cropping in release (the emulator camera shows no face);
- reminders firing;
- the practice games (they need four named people);
- each permission denied in turn;
- a real phone;
- Android 15+ edge-to-edge and predictive back;
- a tablet.

**Eric deploys.** A recommendation to ship is not permission to ship.

## Suggested order

1. Signing and bundle (1).
2. Data safety fixes in code: backup (4), and the photo-loss and corrupt-record fixes (2, 3).
3. Photo size and avatars (5, 6), measured on the phone in a release build.
4. Camera and permission messages, consent line, raw errors (7, 8, 11, 12).
5. Access fixes (9, 10).
6. The integration test (13), then Release readiness.
7. Store actions (section 4), and a closed test track with friends.
