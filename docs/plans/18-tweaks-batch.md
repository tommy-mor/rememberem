# 18. Tweaks batch: inline details, relationships, colours, sounds, crop

Sixteen fixes Eric asked for after using story 17 on his phone, planned and
checked together with a minimal crew. AC = acceptance criteria.

## 1. Details are edited where they are added (also fixes "details don't stick")

Cause of the bug (most likely): "+ fact" opened `DetailEditScreen`, whose only
way to keep the detail is the app-bar **Save** button. Back pops `null`, so a
typed detail vanished (`memory_edit_screen.dart` `_addDetail`). A relationship
also needed a type and a person before Save was enabled.

AC: tapping "+ fact/happening/relationship/anniversary" adds a row to the
Details list on the person page and focuses it; whatever is typed or chosen
there is saved as you go, like every other field; leaving the page (Back,
Home, a merge) keeps it. A row with nothing in it at all is not saved.

Design:
- Delete `detail_edit_screen.dart`. `DetailListEditor` gets an `onAdd(kind)`
  that calls `MemoryEditor.addDetail(Detail(id, kind, text: '', at: now))`.
- `MemoryEditor.addDetail` accepts a blank detail (kept in memory, not saved).
  `flush` drops only **empty** details: blank text and no place, label,
  target or event date (`MemoryEditor._isEmpty`). So a relationship with a
  type and a person but no description is kept.
- Each row's extra data is edited inline by an `DetailExtrasEditor` (new,
  `memories/detail_extras_editor.dart`) shown under the description while
  the row is expanded: happening date/time (pickers) and place; relationship
  person and type; anniversary type and date. A new row starts expanded;
  tapping the row's caption line toggles it. Changes go through
  `MemoryEditor.replaceDetail` (built with `copyWith`, keeps scores).
- `DetailQuizPlanner` already skips blank-text details, so incomplete rows
  never reach a quiz (no core change).

## 2. Compact detail rows; detail text size in Settings

AC: each detail is one text field whose label is its caption plus data on
one line, e.g. "Happening · 3 Mar, 10:00 · Joe's Café" or "Relationship ·
Brother · Ann Lee", ellipsized; no separate "Description" label or prefix
line. Delete is a small trailing icon. Detail text is 80 % of normal by
default; Settings › Display › "Detail text size" (60–150 %, step 10) changes
it, on top of the phone's own text size.

Design: `AppSettings.detailTextPercent` (default 80, clamped, new JSON key;
no migration). The Details section is wrapped in a `MediaQuery` whose
`textScaler` is the ambient scaler × percent / 100.

## 3. Dictation: a ding at start and stop, and a pulsing mic

AC: tapping a mic plays a short ding, then listens; when listening ends
(tap, silence or error) a lower ding plays. While listening the stop icon
pulses. Dings follow the Sounds setting.

Design: `CuedDictation implements Dictation` (`speech/cued_dictation.dart`)
wraps `DeviceDictation` with a `SoundCue` interface (`play(String asset)`),
playing `sounds/listen_start.wav`, waiting 200 ms so the recogniser does not
hear it, and `sounds/listen_stop.wav` on done. Sounds made by
`tool/make_sounds.py`. `DictatedTextField` pulses the icon with a repeating
`AnimationController` only while listening (tests' fake dictation finishes
synchronously, so `pumpAndSettle` still settles; any that does not uses
`pump`).

## 4. Relationships: who first, thumbnails, wording

AC: in a relationship row, "Who" comes first; its menu shows a tiny photo
beside each name; the free-text type box reads "Create a custom relationship
type".

## 5. Relationships list on the person page, both ways

AC: at the bottom of a person page, "Relationships" lists, with a small
photo and name: each relationship on this person (subtitle: the type, e.g.
"Brother") and each relationship on someone else's record that points at
this person (subtitle: "Is their brother"). Only active people show. Tapping
one saves this page and opens theirs.

Design: core `RelationshipIndex.of(Memory person, List<Memory> active)` →
list of `(Memory other, String label, bool outgoing)`
(`packages/rememberem_core/lib/src/relationship_index.dart`, unit-tested).
App `RelationshipsSection` (`memories/relationships_section.dart`) renders
it from the page's `_people` and the editor's current details.

## 6. Photo at the top: left, with Crop and Merge beside it

AC: the person photo sits at the left; to its right, a "Crop" and a "Merge
with existing person record" button. The old Merge button at the bottom goes.

## 7. Colours and dark mode

AC: Settings › Display has "Theme colour" and "Background" swatch rows and a
"Dark mode" switch. Defaults: theme navy `#0A2A7A`; background a light blue
of the logo's hue (`#E8EEFB`). Dark mode uses a dark scheme from the theme
colour and ignores the background choice. Changes apply at once.

Design: `AppSettings.themeColor`, `backgroundColor` (ARGB ints, chosen from
`AppPalette` lists, invalid values fall back) and `darkMode`.
`RememberemTheme.light(settings)`/`dark(settings)`; `RememberemApp` rebuilds
`MaterialApp` from a `ValueListenableBuilder` on the settings.

## 8. Game sounds and haptics actually play

Likely causes on the Galaxy: `respectSilence: true` makes audioplayers use
the ringtone stream (silent on vibrate), and `HapticFeedback.lightImpact`
follows the "touch interactions" system setting, often off.

Design: sounds use the media stream (Android usage `game`, no focus) and a
preloaded `PlayerMode.mediaPlayer` player per sound (stop, seek 0, resume).
Haptics go through a new `Haptics.kt` channel calling `Vibrator` with a
30 ms one-shot (manifest `VIBRATE`, a normal install-time permission).
`DeviceGameFeedback` takes a `Haptics` interface; `HapticFeedback` stays as
the non-Android fallback. Verify on the phone.

## 9. Tapping outside a field closes the keyboard

AC: tapping empty space (not a button or another field) unfocuses the field
and hides the keyboard; typed text is kept (autosave already ran).

Design: `MaterialApp.builder` wraps the app in a translucent
`GestureDetector(onTap: unfocus)`.

## 10. Crop the person's photo

AC: "Crop" opens the representing photo in a 4:5 frame; pinch and drag,
then "Done" replaces the photo with the framed part; "Cancel" changes
nothing. The list, page and practice show the new crop.

Design: core `PhotoCrop.crop(bytes, Rect01)` (pure Dart, `image` package,
JPEG at the pipeline's quality); repository `replaceEncounterPhoto(memory,
photoFileName, bytes)` writes temp then renames, inside the serial chain.
App `CropScreen` uses `InteractiveViewer` and reads the visible rectangle
from its `TransformationController`. The page evicts the old `FileImage`.

## 11. Title is the person's name

AC: the person page's app bar shows the name as typed (or "unknown"), not
"New person".

## 12. Photos: the phone's own picker, and full access

AC: the gallery button opens the phone's gallery picker (Android
`ACTION_PICK` on MediaStore images). If location access to photos is not
fully allowed, the photo still comes in without its location and a snackbar
says "Photo added without its location" with a "Settings" action that opens
the app's permission page.

Design: `OriginalPhotoPicker.kt` uses `ACTION_PICK` (falls back to
`ACTION_OPEN_DOCUMENT` if no app handles it), asks `ACCESS_MEDIA_LOCATION`
whenever it is not granted (Android stops asking after two refusals), and
returns `{bytes, original}`; new method `openSettings`. `PhotoPicker.pick()`
returns a `PickedPhoto(bytes, hasOriginal)`.

## 13–15. Small defaults and labels

- Default "Same place within" is 555 ft (step 50 unchanged; a saved
  settings file keeps Eric's current value).
- The list's practice buttons read "Faces" and "Details".

## Tests

- Editor: blank added detail not saved; relationship with only type and
  person saved; empty row dropped on flush.
- Person page: "+ fact", type, Back → detail in repository (regression).
- Relationship row: Who before type; custom type label text.
- `RelationshipIndex`: outgoing, incoming, trashed excluded, self excluded.
- Relationships section: tap opens the other person's page.
- Settings: new keys round-trip and clamp; detail text percent scales text;
  dark mode switches `ThemeMode`; 555 default.
- `CuedDictation`: start cue before listen, stop cue once on done.
- `PhotoCrop`: output aspect and pixels from the chosen region; repository
  replace keeps the file name and never touches other files.
- Title shows the name; buttons read "Faces"/"Details".
- Device: sounds and vibration on the Galaxy; photo picker and Settings link.

## Out of scope

Undo for a crop; colour pickers beyond the swatch lists; iOS haptics channel.

## Review record

Minimal crew: Tess and Sally (Baseline), Archie (Plan check). No factual
dispute remained, so Vera was not needed at planning. Changes adopted:

- **Empty, not blank** (Tess, Archie): core `Detail.isEmpty` (no text,
  place, label, target or event date). `addDetail`, `replaceDetail` and
  `flush` all use it, so setting a person on a row with no description is
  kept. A relationship with no description is stored but, as today, never
  practised. Tests round-trip each partial kind and check the planner.
- **Crop reuses `PortraitCropper.cropInBackground`** (Archie); no `PhotoCrop`.
  `replaceEncounterPhoto` runs in the serial chain and writes only if the
  person is active and still lists that photo (Tess), else throws.
- **`darkMode` defaults to false**; colours outside `AppPalette` fall back
  (Archie). The theme comes from one `ValueListenableBuilder`; the
  background is the scaffold background.
- **Pulsing mic** stops when listening ends; listening tests use `pump`
  (Tess). `CuedDictation.stop` during the start delay cancels the start
  and plays one stop ding (Tess).
- **Relationships list** uses the editor's own details, reloads people when
  coming back from another page, and skips trashed people (Tess).
- **Photo picker** (Sally): `original` is false whenever the unredacted read
  fails or the URI is not a MediaStore one, so the snackbar tells the truth.
  `openSettings` opens only this app's details page. To verify on the
  emulator (Google Photos) and the phone (Samsung Gallery).
- `VIBRATE` gets a manifest comment (Sally). Crop is destructive by design.
- Declined: `RelationshipIndex` stays in core (Archie suggested app-side):
  it is pure logic and the core is where pure logic is unit-tested.
- Items 13 and 15 were already applied when Archie read the code.
