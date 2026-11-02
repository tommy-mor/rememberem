# 20. Filter list and group photos

Two changes Eric asked for. AC = acceptance criteria.

## 1. Filter list

AC:
- The "Match people" page is renamed "Filter List" (title and the list
  page's button tooltip).
- It opens with no filters, showing everyone. "Add filter" offers Place,
  Meeting, Name contains, Details contain, and Date range. Any number can be
  added, including two of the same kind; a person must match every filter.
- Each filter is one row with its kind as the label and a remove button.
  Place and Meeting pick from the known names (as today). Name contains and
  Details contain are text fields. Date range opens the date range picker.
- A filter not yet filled in (blank text, no place chosen) matches everyone.
- Name contains looks at the shown name, so "unknown" finds people with no
  name (shown as "Unknown").
- Date range matches a person if any encounter falls on a local day inside
  the range, both ends included.
- Nothing is saved, as today.

Design (core):
- `FilterCondition`, an abstract interface: `bool matches(Memory)` and
  `bool get isBlank`. Implementations, one per file: `PlaceFilter(name)`,
  `MeetingFilter(name)`, `NameFilter(text)`, `DetailsFilter(text)`,
  `DateRangeFilter(from, to)`. Place, meeting and details keep today's
  matching rules (`MeetingFinder.samePlace`, case-insensitive detail text).
- `MemoryFilter(List<FilterCondition>)` ANDs the non-blank conditions. It
  replaces the fixed fields; its only user is the matching screen. The
  static `places` and `meetings` helpers stay.

Design (app):
- `MatchingScreen` becomes `FilterListScreen` (file renamed), with optional
  `initialFilters`. It holds `List<({int id, FilterCondition condition})>`,
  and the id keys each row so a text field keeps its state.
- `FilterRow` (new file) draws one row for its condition and reports a
  replacement condition.

## 2. Several faces in one photo

AC:
- A photo with zero faces or one face is saved as today and opens the
  person's page.
- With two or more faces, a "Choose faces" page shows the photo with a box
  on each face. Tapping a box selects or deselects it. "All" selects every
  face. None start selected. The button reads "Add 1 person" or "Add N
  people" and is disabled while nothing is selected.
- With one face chosen, that face is cropped and saved and its page opens,
  as for a single-face photo.
- With several chosen, a "Group details" page shows Place and Meeting,
  pre-filled with what capture would fill in, and lets Fred add any number
  of detail lines (facts, with the mic). "Add N people" creates one record
  per face, each cropped to its face, with that place, meeting and the
  non-blank details, and no name (shown as "Unknown"). Then the Filter List
  opens with a "Name contains: unknown" filter, over the main list (Back
  goes to the list).
- Back from Group details returns to Choose faces. Back from Choose faces
  returns to the list, saving nothing.
- If saving fails partway, the saved people are kept, a message says so,
  and the Filter List still opens, so Fred sees who was saved.

Design (core):
- `CaptureDraft` (new file): the upright photo, its faces sorted left to
  right, `capturedAt`, `location`, and the suggested `place` and `meeting`.
- `PortraitCapture.prepare(...)` does today's work up to the face search
  and the place/meeting lookup, and deletes the work file.
  `saveOne(draft, {face})` crops to `face` (whole photo if null) and adds
  the record. `saveGroup(draft, faces, {place, meeting, details})` adds one
  record per face, then saves the details onto it. `capture()` stays as
  `prepare` then `saveOne(largest face)`, so callers and tests keep working.

Design (app):
- `CaptureScreen` takes the `routeObserver` (it opens the Filter List).
  After `prepare`, two or more faces push `FacePickerScreen` in place of
  the camera.
- `FacePickerScreen` and `GroupDetailsScreen` (new files, `capture/`).
  The group page leaves with `pushAndRemoveUntil(isFirst)` to the Filter
  List.

## Tests

- Core: each filter kind, AND across kinds and within a kind, blank
  conditions, date range ends, "unknown" names. `prepare` sorts faces and
  fills place and meeting. `saveOne` crops the chosen face. `saveGroup`
  creates N records with place, meeting and details.
- App: add, stack and remove filters; the initial filter. Picker: All,
  toggling, the button label, the one-face path, and the group path through
  to the Filter List.

## Review record

Plan check (`archie`) and Baseline (`tess`), with `grace` as witness.

Adopted:
- Wording (`grace`): Choose faces says "Choose only people who are happy
  to be remembered." The details box on Group details is headed "Details
  true of everyone here", with the hint "Each person may read these." The
  Filter List opened after a group save says "Add their names while you
  remember."
- Back from Choose faces asks "Discard this photo?" (Discard / Keep
  choosing), so a stray Back never loses the moment (`tess` 1).
- Choose faces and Group details carry the `capture` route name, so the
  shortcut or a reminder cannot pop them (`tess` 2).
- `MemoryRepository.add` gains `details`, so each group record is one
  write, complete or absent (`tess` 3, `archie` 4). Group details are
  facts timed now, with ids per line; blank lines are dropped. A failure on
  face k keeps faces 1..k-1 and the message gives the count.
- Place and meeting are filled in `prepare`, with the settings' finders,
  and pre-fill Group details (`tess` 4). Faces sort by left, then top.
  The date range picker always returns both ends in order.
- `prepare` deletes the work file in `finally` (`tess` 5).
- `CaptureScreen` gets the `routeObserver`; both call sites are updated
  (`archie` 1). Every capture goes through `prepare`, then `saveOne` (zero
  or one face) or the picker; `capture()` stays for the core tests.

Accepted: if Android kills the app while Choose faces is open, the photo
is lost. Saving the whole photo first would make a record of people Fred
may not choose, which `grace` would object to.

## Gate record

`hal`, `tess`, `rex` and `ada`, then `vera` (go).

Fixed:
- Back during the group save: Group details holds Back while saving, so a
  retry cannot save the faces twice (`rex`, `tess`).
- A double tap on "Add N people" pushed the group page twice (`rex`).
- A widget test through the real `PortraitCapture`, so the app fake cannot
  hide the seam (`tess`).
- Access (`ada`): a dark edge on unchosen face boxes, 48 dp face targets,
  a taller "Add filter", a date range field that is one button, "Choose
  all faces" and numbered "Remove detail" labels. Choose faces keeps its
  Add button in the bottom bar, clear of messages (found on the emulator).
- Each group member gets their own detail ids, so an edit to one copy
  survives merging two of them (`vera`).
- A stale test title (`hal`).

Refuted: an unhandled error from the place lookup in `prepare`
(`_knownPeople` catches everything).
