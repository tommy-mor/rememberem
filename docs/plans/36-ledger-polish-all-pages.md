# Story 36: Ledger polish, every page

## What Eric asked

"Make the app feel more professional. Keep the navy + gold look and the
dense, vertical layout. Show as much as possible at a glance with as few
gestures as possible." Eric picked direction **1c Ledger** from the design
canvas (`Rememberem Polish.dc.html`, section 1c). It is compact and
structured, made for someone who has met hundreds of people.

Sections 1–4 are the four screens drawn on the canvas. Sections 5–15 carry
the same rules to every other page, so the whole app reads as one system.

This plan was reviewed by a slim Plan check crew (archie, marlin, gill)
and a slim Baseline crew (tess, hal, rex), with ada as witness. The
review had one round each way, and vera settled the facts. Their
amendments are folded in below. The exchange is recorded in
`docs/reviews/plan-36-exchange.md`. Checked at commit 24e2922, Flutter
3.47.9.

**Visual only, apart from the behaviour changes listed in "Behaviour
changes", each with its own test.** It changes no data, model, JSON or
settings, and adds no permissions or packages.

## Behaviour changes

Eric accepts these by approving the plan.

1. **Merge picker.**
   - Today a tap on a row picks and merges at once: it pops the person,
     and `MemoryEditScreen._merge` merges.
   - Now a tap selects the person, a second tap on the same row deselects
     them, and the Merge button pops the person.
   - `_merge` is unchanged. The button disables itself as soon as it is
     pressed.
2. **Trash rows** are grouped by trash date, and Restore becomes a pill.
   There is **no** "Empty trash" action: bulk purge is out of scope.
3. **Timeline.**
   - "Show details" moves from a `CheckboxListTile` to an app bar toggle.
   - The toggle is an icon plus the visible word "Details", with
     `Semantics(toggled:)`.
4. **PulsingButton.**
   - It pulses three cycles and then stays tinted.
   - It restarts when its card is expanded.
5. **Undo snack bars** last 10 s instead of 6 s. These are the ones at
   `memory_edit_screen.dart:638` and `:686` and
   `detail_list_editor.dart:189`.
6. **Home list.**
   - The list refreshes on app resume, so the date groups stay right
     across midnight. This is new: today only `RememberemApp` handles
     resume.
   - If Home's four app bar actions don't fit at 320 dp, Timeline, Places
     and Trash move to an overflow menu. Decide this in slice 1.
7. **Layout moves.**
   - Home's Filter and sort become pills.
   - The contact link moves to the app bar.
   - The Capture gallery button moves.
   - Faces quiz answers become a list.
   - Details quiz answers become a 2 × 2 grid.
   - Loading spinners become a linear bar.

Dropped from the canvas: "Play again" on quiz results. Replaying at once
is massed practice, not spaced practice.

## Design rules (apply everywhere)

- **Colours from the theme only.** In the mock:
  - teal `#005B4F` stands for `scheme.primary` (Fred's theme colour, navy
    by default);
  - `#FCEFC7` for `scheme.surface`;
  - `#FFF3D6` for `RememberemTheme.paleGold`;
  - `#E4BC52` for `gold`;
  - `#001952` for `deepNavy`;
  - `#6A604A` for `scheme.onSurfaceVariant`.

  Light and dark themes must both work, and `theme_contrast_test.dart`
  must stay green.
- **One gutter: 16 dp** left and right on every screen. The list text,
  section headers, card fields and quiz content all start on that line.
- **Icons:** `Icons.*_rounded`, with no new icon package. 22 dp in app
  bars, 20 dp inline.
- **Tap targets: 48 × 48** everywhere (`androidTapTargetGuideline`). A
  smaller visual (a 30 dp pill or add button, the crop button) gets a
  48 dp tap area. Leave 8 dp between neighbouring hit areas.
- **Type:** keep the current text theme.
  - Section headers are an overline: 12 sp, weight 800, letter-spacing
    1.1, all caps, `onSurfaceVariant`.
  - Field labels are at least 12 sp, subtitles at least 13 sp.
  - No `google_fonts`. Manrope only as a bundled asset, if Eric asks.
- **Heights are minimums.** Every row, strip and bar height in this plan
  is a `minHeight`. Text at 2.0 scale grows the row; it never clips.
- **Rules, not boxes.** Rows are separated by a 1 dp divider at 8 % of
  `onSurface`, inset to start at the text, not under the photo.
- **Selection is never colour alone.** A selected or right row also shows
  a check icon and carries `Semantics(selected: true)`.
- New shared constants (gutter, thumb sizes, overline style) go in
  `RememberemTheme`, not in a tokens file.

## Shared pieces and theme

Use the theme first, and add a widget only when there is reuse. Each
widget is built in the first slice that uses it, under
`app/lib/src/app/`, one class per file.

- **App bar: theme, not a widget.**
  - `AppBarTheme` sets `toolbarHeight: 52` and the title style (18 sp,
    weight 700). The Scaffold lays the bar out at the theme height
    (`AppBar.preferredHeightFor`, `scaffold.dart:3051`).
  - Actions are 48 wide.
  - `RememberemTheme.titleWithSuffix(context, title, suffix)` builds a
    `Text.rich`. The suffix is the bar's foreground colour at 75 %, tested
    at 4.5:1 or better on the bar in both themes.
  - The 18 `AppBar(...)` sites stay. Capture overrides `backgroundColor`
    to black.
  - `HomeButton` stays the last action.
- **Fields: `RememberemTheme.ledgerDecoration(theme, {label, hint,
  suffix})`.** It returns an underlined `InputDecoration` with an
  always-floating overline label (12 sp, weight 800, caps).
  - Unfocused: `onSurface` at 60 %, 1.5 dp, at least 3:1 on light, dark
    and the six backgrounds (`theme_contrast_test`).
  - Focused: `primary`, 2 dp, and the label turns `primary`.
  - **`inputDecorationTheme` is not changed.**
  - `DictatedTextField(ledger: true)` uses the helper. The plan says what
    happens with `showMic: false` and with a hint
    (`dictated_text_field.dart:151` already sets `floatingLabelBehavior`
    when there is a hint).
  - Dialog and filter fields keep their current decoration.
  - **Call-site table (built in slice 1, kept up to date):** every
    `TextField`, `TextFormField`, `DropdownMenu` and `DictatedTextField`,
    with file:line and its expected border (underline or outline).
  - **Tests:**
    - the mic button is at least 48 × 48 under `ledger: true`;
    - a dense ledger field is at least 48 dp tall. The suffix makes it so
      unless a compact `VisualDensity` is inherited
      (`input_decorator.dart:1109-1128`, `:2512-2516`); test it, don't
      assume.
  - **The call-site table** (built in slice 1, at commit 24e2922 plus
    slice 1; no `DropdownMenu` exists, the nearest is a
    `DropdownButtonFormField`):

    | File:line | Field | Border now | Border after | Slice |
    | --- | --- | --- | --- | --- |
    | `speech/dictated_text_field.dart:192` | the `TextField` inside every `DictatedTextField` | outline, or ledger when `ledger: true` | ledger when asked; otherwise no explicit border (the theme's own; the explicit outline was deleted in slice 2, and only `group_details_screen` still asks for the plain look until slice 6) | 1, 2 |
    | `memories/memory_edit_screen.dart:458` | Name, Place, Meeting (one `DictatedTextField` in a loop) | outline | ledger (done) | 2 |
    | `memories/detail_list_editor.dart:355` | detail Description | outline, dense | ledger (done) | 2 |
    | `memories/detail_extras_editor.dart:261` | Who (`DropdownButtonFormField`) | outline, dense | ledger (done) | 2 |
    | `memories/detail_extras_editor.dart:193`, `:215`, `:238`, `:337`; `memories/encounter_edit_screen.dart:70`, `:75` | Date, Place and Time pickers (new `LedgerPickerField`, an `InputDecorator`, not typed into) | (were list tiles and buttons) | ledger (done) | 2 |
    | `memories/encounter_edit_screen.dart:185`, `:195` | Place, Meeting | outline | ledger (done) | 2 |
    | `capture/group_details_screen.dart:129`, `:137` | Place, Meeting | outline | ledger | 6 |
    | `capture/group_details_screen.dart:154` | each face's Detail (name) | outline | ledger | 6 |
    | `places/place_row.dart:270` | place name (`TextField`) | outline (`:280`) | ledger | 4 |
    | `memories/filter_row.dart:97`, `:103` | Name and Details filters (`TextFormField`) | underline (default) | unchanged | - |
    | `memories/filter_row.dart:127` | the tappable filter fields (`InputDecorator`) | underline (default) | unchanged | - |
    | `maps/place_name_dialog.dart:33` | Place in the name dialog | outline (`:39`) | unchanged (dialog) | - |
    | `memories/new_type_dialog.dart:39` | Name in the new-type dialog | underline (default) | unchanged (dialog) | - |
    | `settings/settings_section.dart:23` | the section box (`InputDecorator`) | outline, local theme | deleted (done; Settings has no text fields, so none left in slice 5) | 5 |

- **Progress bars:**
  - no global `linearMinHeight`;
  - each `LinearProgressIndicator` passes its own `minHeight`: 3 under
    the app bar, 6 on the badge, 6 on results;
  - indeterminate bars replace full-screen `CircularProgressIndicator`s
    where a list or quiz is loading.
- **`SectionHeader({title, count, trailing, tinted})`**
  (`app/section_header.dart`). It is one widget for both the tinted
  30 dp strip and the untinted list-group header.
  - The tint is `RememberemTheme.shade(theme, scheme.surface)`.
  - The trailing add button has a 48 dp tap area.
  - It replaces the ad-hoc headers at `relationships_section.dart:33`,
    `detail_list_editor.dart:234`, `group_details_screen.dart:144` and
    `settings_section.dart`.
  - `DetailListEditor.tintOf` is deleted.
- **`PortraitThumb`:** the 4:5 photo in four sizes: 24 × 30, 38 × 48,
  44 × 55 (Timeline) and 136 × 170 (cards). The radius is 5 for the
  smallest, 7 for the two middle sizes and 9 for cards.
  - Keeps a `ResizeImage` sized to the thumb, and the error fallback, in
    one place.
  - Each thumb has a semantics label with the person's name.
- **`BottomActionBar`:** a `paleGold` bar, at least 46 dp, with a top
  divider. It includes `viewPadding.bottom` and the primary action is
  gold, on the right.
- **Selected-row style:** a 3 dp `primary` leading bar, a 6 % `primary`
  tint, a check icon and `Semantics(selected: true)`. Built for Merge in
  slice 2, and reused for Places.
- **`EmptyState`:** a flush-left block 32 dp below the app bar. It has a
  20 sp, weight 800 line, one line of help, and at most one button. Built
  only once it has three callers (Home, Timeline, Trash).
- **No `LedgerRow`** for now. Rows stay `ListTile`s, styled through
  `ListTileThemeData`. Extract a widget only when one slice shows the
  same shape twice.
- **Dialogs** (`DialogThemeData`): radius 16, 16 dp gutter, title 18 sp
  weight 800, body `bodyMedium`, actions in one row at the bottom right.
  The main or destructive action is last and filled. Delete any per-site
  `shape` on `AlertDialog(`.
- **Snack bars** (`SnackBarThemeData`):
  - radius 10;
  - `deepNavy` with `gold` action text on light pages;
  - on dark pages, `surfaceContainerHigh` with a 1 dp outline and an
    action of at least 4.5:1.
  - `behavior: fixed` (Eric's choice), which already sits above
    `bottomNavigationBar`. The Undo bar stays tappable while a snack bar
    shows. A test taps ↶ while a snack bar shows, after it times out,
    and with the keyboard up.

## 1. Home (`memory_list_screen.dart`, `memory_tile.dart`, `progress_badge.dart`, `filter_bar.dart`)

```
[logo]                    ⟲  📍  🗑  ⚙        app bar, 52 dp
8 people           (⚟ Filter) (Date met ↓)    count bar, 44 dp, divider below
THIS WEEK                                     group header
[▯] Inge Jorgensen                   ▬▬▭      row, 58 dp min
    home
OCTOBER
[▯] Alice leese                      ✓
    home
──────────────────────────────────────────
[Faces] [Details]  Remembered          [📷 Meet]   bottom bar, 68 dp
                   1 face · 0 details
```

- **App bar:** logo on the left. Timeline, Places, Trash and Settings as
  48 dp `IconButton`s with tooltips. Check this at 320 dp (behaviour
  change 6).
- **Count bar:** "N people" (weight 800, 15 sp) on the left. Filter and
  sort are 30 dp pills with 48 dp tap areas:
  - Filter is outlined in `primary` at 30 %;
  - sort is filled with `primary` at 10 % and shows the field and the
    direction arrow.

  They open the same things as today.
- **Group headers by date met** when the list is sorted by date. They use
  `SectionHeader(tinted: false)` and `DateGroups`. For other sorts there
  are no headers.
  - **Where the logic lives:** `DateGroups`
    (`app/lib/src/memories/date_groups.dart`), a pure class given a clock.
    `rememberem_core` is unchanged.
  - **Buckets:**
    - "This week" runs from Monday 00:00 local time until now. A future
      date also goes in "This week".
    - "Last week" is the seven days before that.
    - Then month names ("October") for this year, and "October 2025" for
      earlier years.
    - Home has no "Today" bucket.
  - **Which date counts:** the newest encounter.
  - **Order:** the groups follow the sort direction.
  - **Structure:** headers and rows go into one flat item list inside
    `ListView.builder`. No slivers.
  - **Refresh:** the groups are worked out in `build` from the injected
    clock. `MemoryListScreen` gets a resume observer that calls
    `setState` (new work).
- **`MemoryTile`:**
  - leading is a 38 × 48 `PortraitThumb`, with a 12 dp gap to the text;
  - title 15 sp, weight 700;
  - subtitle 13 sp, `onSurfaceVariant`, `maxLines: 2` (a short subtitle
    stays on one line), order "place · meeting";
  - row height at least 58 dp;
  - the divider sits under the text column only;
  - the `below` slot (filter match lines) starts at the thumb width plus
    the gutter plus the gap (66 dp), replacing the hard-coded 72 at
    `memory_tile.dart:70`.
- **`ProgressBadge`:**
  - a 48 × 6 bar, radius 3, with a 1 dp `primary` outline;
  - the track is `primary` at 16 % and the fill is `primary`;
  - fill against track, and outline against surface, at least 3:1 in both
    themes;
  - when remembered, a filled `check_circle` (20 dp) in a named green
    that reaches at least 3:1 on both backgrounds;
  - the semantics label is unchanged;
  - `progress_pie_painter.dart` is deleted.
- **Bottom bar** (68 dp, `paleGold`, top divider):
  - Faces and Details as icon-over-label buttons;
  - the Remembered summary as two lines (the label at weight 800, then
    "1 face · 0 details");
  - **Meet** as the gold primary button on the right (46 dp tall, radius
    12, filled camera icon). Meet stays the largest target on the
    screen.

## 2. Person card (`memory_edit_screen.dart`, `when_where_row.dart`, `detail_list_editor.dart`, `relationships_section.dart`, `pictures_section.dart`)

```
←  Anna wood                 🗑  👤  🏠
┌──────┐ NAME
│ 4:5  │ Anna wood          (primary underline 2)
│photo │ PLACE
│   ✂  │ home               (faint underline 1.5)
└──────┘ MEETING
         drama club
🕒 Nov 4, 2:14 pm · Snohomish          ⑂ Merge
FACTS 2                                    +   tinted header, 30 dp
Dyed her hair pink for the spring play     ⌄   row, 48 dp
HAPPENINGS 1                               +
┌ DATE ──────── PLACE ──────────────┐   expanded item: raised card
│ DESCRIPTION (focused)             │
│ ?            ⌃            🗑      │
└───────────────────────────────────┘
RELATIONSHIPS 1                            +
[▯] Friend of Anders Lily                  ⌄
ANNIVERSARIES 0                            +
──────────────────────────────────────────
↶          Saved · 2 changes          ↷      46 dp
```

- **Header block:**
  - A top-aligned `Row`, as today (`memory_edit_screen.dart:382-387`),
    with no fixed height.
  - The portrait sits on the left at 136 × 170 (Eric's choice). A tap on
    it opens the full photo. It has a crop button with a 28 dp visual and
    a 48 dp tap area in its bottom-right corner.
  - Name, Place and Meeting are stacked on the right, using
    `ledgerDecoration` through `DictatedTextField(ledger: true)`.
  - The mic behaviour is unchanged.
- **When/where line** (38 dp):
  - a clock icon, then the date, time and place at 13 sp in
    `onSurfaceVariant`;
  - Merge on the right as a `primary` text button;
  - this moves Merge below the photo, so `memory_edit_screen_test:523-553`
    is changed on purpose.
- **Section headers** (Facts, Happenings, Relationships, Anniversaries,
  Tags) use `SectionHeader(tinted: true)`. Each shows the title, its count
  and the add button. Empty sections still show their header.
- **Collapsed detail rows:**
  - at least 48 dp tall;
  - one line with an ellipsis;
  - an `expand_more` on the right;
  - a relationship row leads with a 24 × 30 `PortraitThumb`.
- **Expanded detail:**
  - a card inset 10 dp, radius 12, a lighter fill than the page, and a
    1.5 dp `primary` outline with a soft shadow;
  - ledger fields inside it, with Date and Place side by side, then the
    Description;
  - an action row: help, collapse, delete.

  Keep story 19's rule that tapping outside closes the card.
- **Pictures section:** same content, under a `SectionHeader`.
- **Undo bar:** stays in `bottomNavigationBar` as a `BottomActionBar`.
  Undo is on the left, "Saved · N changes" in the centre and redo on the
  right. Disabled buttons are at 35 % opacity.

## 3. Faces quiz (`face_game_screen.dart`)

- **Title:** keep the existing title, "Turn N of M". No muted suffix
  here.
- **Progress:** a 3 dp bar just under the app bar, with the track
  `primary` at 18 % and the fill `gold`. It replaces any other progress
  display.
- **Photo:**
  - Full gutter width, radius 12, `BoxFit.cover`.
  - A `LayoutBuilder` sizes it on every build, never from a cached
    value. The reveal phase reserves the height of the four answer rows
    and the question, so the photo never jumps when the answers appear.
  - The photo is at least 200 dp tall. If the page doesn't fit, it
    scrolls with the photo on top.
- **Question:** "Who is this?" at 16 sp, weight 800.
- **Answers:**
  - One list in a rounded card (radius 12) with a hairline outline.
  - Rows are at least 54 dp, with the name at 16 sp, weight 700. The
    whole row is the tap target.
  - There are no number tiles.
- **Right and wrong:**
  - A right answer turns the row green (the existing `rightStyle`), adds
    a `check_circle` and sets `Semantics(selected)`.
  - A wrong answer is dimmed to 35 % and disabled. It is never red, and
    is announced as "not this one".
  - Sounds and haptics are unchanged.

## 4. Details quiz (`detail_game_screen.dart`)

- **Header:** the same title rule and 3 dp bar as the Faces quiz.
- **Prompt block:**
  - a small outlined type chip ("FACT", "HAPPENING"…, at least 12 sp,
    weight 800, radius 6) and "Who is this about?" on one line;
  - then the detail text at 21 sp, weight 800, `TextAlign.start`, at most
    3 lines. It shrinks to 19 sp before it is cut off with an ellipsis.
- **Answers:** a 2 × 2 grid of cards (gap 10, radius 12). Each card has:
  - the 4:5 photo on top, `clamp(120, space left, 188)` dp tall;
  - then a name strip at least 48 dp tall. Names wrap to two lines and
    are at least 13 sp.
- **Small screens:** if four cards at 120 dp don't fit (large text,
  landscape), the whole body scrolls.
- **Right and wrong:** marked as in the Faces quiz. A right card gets a
  corner check.

## 5. Timeline (`timeline_screen.dart`, `timeline_miniature.dart`)

```
←  Timeline                       ☐ Details  🏠
TUESDAY, 4 NOVEMBER 2026                  ›    group header, opens the day
home · drama club                              13 sp weight 700, primary
[▯] [▯] [▯] [▯] [▯]                            44 × 55 thumbs + first name
Anna Bo  Lily  Ed   Kim  Sam
Anna wood – Happening: Our Town                13 sp, one line, ellipsis
```

- **Details toggle:** an icon plus the word "Details", with
  `Semantics(toggled:)` and a fixed label (behaviour change 3). The test
  checks that the detail lines appear and disappear.
- **Day headers:** `SectionHeader(tinted: false)` with a `chevron_right`
  when the header opens a day page. No 24 dp indent; everything starts at
  the gutter.
- **Separator:** place and meeting groups use " · ", as Home does.
- **`TimelineMiniature`:** a 44 × 55 `PortraitThumb` in a 52 dp-wide
  cell, with the first name underneath at 12 sp on one line (Eric's
  choice).
  - Every thumb carries `Semantics(label: full name, button: true)` and a
    48 dp tap area.
  - Thumbs wrap in rows with a 6 dp gap.
- **Day page:** shows the date as the title and the people count as the
  muted suffix.
- **Empty and error states:** `EmptyState`, either "No one yet." with
  "Meet someone", or "Could not load the timeline." with "Retry".

## 6. Places (`places_screen.dart`, `place_row.dart`, `places_map.dart`, `radius_slider.dart`)

- **Header:** the title is "Places", with the count as the muted suffix.
- **Map:** keeps its height and gestures, with a 2 dp `primary` rule
  along its bottom edge.
- **`PlaceRow`** keeps story 35's three lines.
  - Line 1: the place icon in a 38 dp slot, then the name as a ledger
    field labelled "PLACE". This removes the outline at
    `place_row.dart:280`.
  - Line 2: the radius as a 30 dp pill (48 dp tap area), then "Notify"
    and its checkbox.
  - Line 3: the expander and a 13 sp summary.
  - The selected row uses the selected-row style.
  - Expanded people are `MemoryTile`s, one per line, indented to the text.
- **`RadiusSlider`:** a 48 dp row with the value, the slider and a check
  button.
- **Scroll maths:**
  - The estimate (`places_screen.dart:176-178`) drops the
    `(people.length / 2).ceil()` term for one tile per person.
  - `collapsedExtent` (`place_row.dart:31`) is set from a measurement.
  - Tests:
    - measure a collapsed row, and the people rows at 1 and 3 people, at
      scale 1.0 and 2.0;
    - with 12 places, expand one above the last, select the last, and
      assert its `getRect` lies inside the `ListView`'s rect, at 1.0 and
      2.0.

## 7. Capture (`capture_screen.dart`, `photo_check.dart`, `face_picker_screen.dart`, `face_box.dart`, `group_details_screen.dart`)

Capture stays black, because it is a camera. Only the chrome changes.

- **App bar:** black, white text, "Meet someone".
- **Shutter row:**
  - a 76 dp gold shutter with a 3 dp white ring and a `deepNavy` camera
    icon;
  - a 48 dp gallery button (radius 12, white at 15 %) on the right, and an
    empty slot on the left;
  - it respects `viewPadding.bottom`.
- **Consent line:** 13 sp, white at 85 %, at the gutter, with the switch
  on the right.
- **"Framing the photo…":** keeps its scrim, with an indeterminate 3 dp
  bar under the app bar and the text flush left.
- **`PhotoCheck`:** a black `BottomActionBar` with "Retake" on the left
  and "Use photo" (gold) on the right.
- **Face picker:**
  - face boxes are 2 dp `gold`, radius 6;
  - the picked face is filled `gold` at 25 % and gets a check icon;
  - a `paleGold` strip says "Tap the face to keep".
- **`GroupDetailsScreen`:**
  - each face gets a row at least 58 dp tall, with a `PortraitThumb` and a
    ledger name field;
  - Place and Meeting are at the top;
  - "Save N people" is gold in a `BottomActionBar`.
- **Rotation:** capture is not locked to portrait. The manifest has no
  `screenOrientation`, and iOS allows landscape. No new landscape layout
  is built, but the controls must not overflow at 568 × 320. This is
  checked on a device.

## 8. Crop (`crop_screen.dart`)

- The title is "Crop" with a close button and a check action.
- The frame is a 2 dp white rectangle with `gold` 16 dp corner handles,
  and a 55 % black scrim outside it.
- A `BottomActionBar` has "Reset" on the left and "Done" (gold) on the
  right.

## 9. Encounter edit and when/where (`encounter_edit_screen.dart`, `when_where_row.dart`, `location_picker_screen.dart`, `location_choice.dart`)

- **Encounter edit:**
  - Fields use ledger fields: DATE and TIME side by side, then PLACE and
    MEETING.
  - The photo is a `PortraitThumb` at the top left, the same size as the
    person card's.
- **`LocationPickerScreen`:**
  - The map is styled as on Places.
  - The chosen place shows in a `paleGold` strip at least 58 dp tall over
    the bottom of the map.
  - "Use this place" is the gold action.
- **`LocationChoice`:** each option is a `ListTile` with a leading radio.

## 10. Merge picker (`merge_picker_screen.dart`)

- **Title:** "Merge Anna wood into…".
- **Pinned strip:** shows the person being merged (a 38 × 48 thumb, the
  name, and "will be merged into the person you pick").
  `merge_and_pictures_test:144-146` (`find.text('Me')`) is rewritten so
  the strip doesn't break it.
- **List:** Home's list (`MemoryTile`, grouped by date met). The source
  person is already excluded (`merge_picker_screen.dart:40`).
- **Picking:** behaviour change 1. The pick is kept in `State` by id, so
  it survives rotation. A `BottomActionBar` shows "Merge" (gold) once a
  person is picked.

## 11. Trash (`lib/src/trash/trash_screen.dart`, `purge_confirm_dialog.dart`)

- **Title:** "Trash", with the count as the muted suffix. There is no bulk
  action.
- **Rows:** `MemoryTile`s grouped by `trashedAt`. The buckets are "Today"
  (since local midnight), "This week", then months.
- **Trailing:** a "Restore" pill in `primary`, then a 48 dp
  `delete_forever` button in `error`, which opens the existing
  per-person confirm.
- **Empty state:** "Trash is empty." / "People you delete wait here until
  you delete them forever."

## 12. Settings (`settings_screen.dart`, `settings_section.dart`, `setting_stepper.dart`, `colour_choice.dart`, `reminders_section.dart`)

- **Sections:** `SettingsSection` is replaced by `SectionHeader(tinted:
  true)` and `settings_section.dart` is deleted. It had its own local
  `InputDecorationTheme`.
- **Switch rows:** `SwitchListTile`s, styled through the theme.
  - The title is 15 sp, weight 700.
  - The subtitle is 13 sp, up to 3 lines. The Street maps note must stay
    whole, because it is the privacy explanation.
- **`SettingStepper`:**
  - The label is on the left.
  - On the right is one outlined pill: −, the value (weight 800, at
    least 64 dp wide) and +.
  - The buttons are 48 dp.
  - `tabularFigures` is used only if Roboto supports it (check this).
- **`ColourChoice`:**
  - Swatches are 32 dp squares with radius 8 and gap 8, each with a 48 dp
    tap area.
  - The chosen swatch has a 2 dp `onSurface` ring and a check.
  - The swatches wrap on narrow phones.
- **About link:** the last row, with `chevron_right`.
- **Debug items:** keep their own "DEBUG" header and stay hidden in
  release builds (`kDebugMode`).

## 13. About and consent (`about_screen.dart`, `debug_section.dart`, `place_notice_consent.dart`, `allow_in_settings.dart`)

- **About:**
  - The header block is flush left: the logo at 48 dp, the name at 20 sp
    weight 800, and the version at 13 sp.
  - The links (privacy policy, contact, licences) are rows with
    `open_in_new`.
  - The privacy text sits under a "YOUR DATA" header, as `bodyMedium`
    paragraphs.
- **`PlaceNoticeConsent`:** readability wins over density.
  - The title is 21 sp, weight 800, and the paragraphs are `bodyLarge`.
  - The body scrolls above a `BottomActionBar` with "Not now" on the left
    (a full 48 dp button) and "Turn on" (gold) on the right.
  - **No wording changes.**
- **`AllowInSettings`:** uses the dialog theme.

## 14. Practice extras (`quiz_results_view.dart`, `filtered_practice_screen.dart`, `countdown_button.dart`, `mute_button.dart`, `practice_screens.dart`)

- **Quiz results:**
  - The header block keeps the existing "N of M right first try"
    headline (28 sp, weight 800), with a full-width 6 dp gold bar under
    it.
  - The results are in two `SectionHeader`s, "See again soon" and then
    "Got it", with the missed people first.
  - Each row has a 38 × 48 thumb, the name, and for details the question
    as the subtitle.
  - Kept as they are: `missText` ("You'll see them again soon."), the
    "You remember X now!" banner, the star on each row, and "Done".
- **`FilteredPracticeScreen`:** the active filter shows as pills in a
  44 dp strip under the app bar.
- **`CountdownButton`:**
  - During the reveal the choices stay hidden, as they do now.
  - Only the "Show names" / "Show people" button changes: a thin gold bar
    drains across it instead of filling.
  - Tapping skips the wait, as now.
- **`MuteButton`:** `volume_up` / `volume_off`, in the app bar only.

## 15. Small parts (`person_chip.dart`, `remembered_label.dart`, `filter_row.dart`, `filter_match_lines.dart`, `detail_extras_editor.dart`, `pulsing_button.dart`, `contacts/contact_link_button.dart`)

- **`PersonChip`:** a 30 dp pill with a 24 × 30 `PortraitThumb` at its
  left edge, and the name at 13 sp, weight 700. Its `CircleAvatar`
  (`person_chip.dart:22`) is deleted.
- **`FilterRow` / `FilterBar`:**
  - each active filter is a pill with a close icon;
  - the filter fields keep their current decoration.
- **`FilterMatchLines`:** 12 sp `onSurfaceVariant`, with the matched words
  at weight 700 in `primary`. They start at the 66 dp text line.
- **`DetailExtrasEditor`:** ledger fields in rows of two where they fit
  (Date + Place, Type + Person). This removes the outline at
  `detail_extras_editor.dart:301`.
- **`PulsingButton`:**
  - tinted `gold` at 35 %;
  - a status listener counts three cycles;
  - it restarts on expand through `didUpdateWidget` or a key, **not** from
    `didChangeDependencies`. Today that method restarts it on every
    MediaQuery change (`pulsing_button.dart:27-35`);
  - with `disableAnimations` it shows full tint.
- **`ContactLinkButton`:** an app bar action (`contact_page`), filled when
  a contact is linked.

## Strings

Daphne owns this list. Any user-facing string not listed here stays as it
is.

| String | Where | New / changed |
| --- | --- | --- |
| "See again soon", "Got it" | quiz results headers | new |
| "Details" | Timeline toggle label | changed (was the "Show details" checkbox) |
| " · " separator | Timeline groups | changed (was " - ") |
| "Tap each face to keep" | face picker strip (multi-pick) | new |
| "Choose only people who are happy to be remembered." | face picker paragraph | changed (dropped "Tap each face to remember.", now in the strip) |
| "Quizzes to help you remember..." | Home bottom bar, above the practice buttons | kept from story 31 |
| 'Tap "Meet" to take a photo.' | Home empty state | changed (the button reads "Meet") |
| "Restore" | Trash pill | new label (was an icon) |
| "will be merged into the person you pick" | merge picker strip | new |
| "Merge" | merge picker button | new |
| "Trash is empty." / "People you delete wait here until you delete them forever." | Trash empty state | new or changed |
| "No one yet." / "Could not load the timeline." / "Retry" | Timeline states | check against current text; changed if different |
| Muted suffixes (counts, dates) | Places, Trash, Timeline day | new |

## Tests

- **Golden-free.** Widget tests only. Find widgets by semantics label or
  text rather than widget type.
- **Each slice's checklist:**
  - Grep `app/test` for every widget type, string and layout the slice
    replaces, including `ListTile` counts, and update those tests in the
    same commit.
  - Run `look_capture_timeline_test` first in slice 1, as a canary.
- **Known tests to update:**
  - `look_capture_timeline_test`: lines 40-61 (SettingsSection) and
    340-356 (the checkbox).
  - `merge_and_pictures_test`: lines 45-51 (`mergeInto` and its callers
    at 91, 110 and 121), 144-146 and 163-170.
  - `back_navigation_test:188`.
  - `memory_edit_screen_test`: lines 49 and 474 (pulse beats) and
    523-553 (layout).
  - `detail_cards_test:38`.
  - The `SwitchListTile` finders in `place_notices_test`,
    `anniversary_notices_test` and `place_radius_test`.
  - `place_radius_test`: lines 229 and 269-280.
  - `places_notify_test:93`.
  - `list_filters_test`: lines 271 and 486.
  - `quiz_results_test:137`.
  - `remembered_metric_test`: lines 140-147.
  - Also: `memory_list_screen_test`, `face_game_test`, `detail_game_test`,
    `layout_batch_test`, `settings_test`, `trash_test`,
    `about_screen_test` and `group_capture_test`.
- **New tests:**
  - **`DateGroups`**, built from local `DateTime`s:
    - a week boundary;
    - a change of year;
    - Monday at 00:00;
    - a UTC `capturedAt` that is Sunday evening or Monday morning locally
      under a negative offset;
    - a DST week;
    - a future date, which lands in "This week";
    - ascending order;
    - a filter that empties a group, so no header shows;
    - the newest encounter counts;
    - the clock crossing Monday 00:00 between two pumps;
    - Trash's "Today" bucket.
  - **Progress bar:** its semantics match the old pie's, and the contrast
    of the fill, track, outline and green check.
  - **Accessibility and overflow table** (`ledger_a11y_test.dart`): a
    table of `(name, builder)` entries.
    - **Covers** Home, Trash, Merge, Settings, About, the consent page,
      Timeline, Faces, Details, Results, the person card (collapsed,
      with one detail expanded, and with the keyboard up:
      `viewInsets.bottom` 300 at scale 2.0).
    - **Before checking,** each entry asserts a marker such as a name or
      title, so an empty state can't pass.
    - **Themes:** each entry runs in light and dark, with a light and a
      dark chosen background.
    - **Checks:**
      - `androidTapTargetGuideline` at scale 1.0 and 2.0;
      - `textContrastGuideline` at scale 1.0;
      - no overflow at 320 × 568 and scale 2.0;
      - Faces and Details also at 568 × 320.
    - Disabled, dimmed wrong answers are exempt, with a finder and a
      comment.
    - **Waivers:** slice 1's spike ends with FIX or WAIVE for each
      failing control. A waiver is a named row (control, file:line,
      reason, Eric's sign-off) that the test reads. An unwaived control
      fails. Nothing uses `skip`, and no screen is excluded wholesale.
    - **Not in the table:** Capture, the maps, Crop and the face picker
      are checked on a device instead.
  - **Person card:** with every section empty, each header and its add
    button still show.
  - **Timeline toggle:** the detail lines appear and disappear.
  - **Merge picker:**
    - a row tap doesn't pop;
    - tapping the picked row deselects it;
    - Merge pops exactly one person;
    - a double tap pops only once;
    - the pick survives a rotation;
    - the failed-merge test is kept, and the card makes one `merge` call.
  - **PulsingButton:**
    - `pumpAndSettle` completes after 3 cycles and the tint stays;
    - collapse then expand restarts it;
    - a MediaQuery change after the 3 cycles doesn't restart it;
    - with `disableAnimations` it shows the full tint;
    - the "never settle" beats are rewritten.
  - **Places:** the measurement and scroll tests in §6.
  - **Fields:** the mic is at least 48 × 48, a ledger field is at least
    48 dp tall, and the underline contrast passes.
  - **Snack bars:** ↶ stays tappable while a snack bar shows, after it
    times out, and with the keyboard up.
  - **App bar suffix:** at least 4.5:1 in both themes.

## Order of work

Each slice is one green check-in: the checks in `CLAUDE.md`, then the
Gate crew plus `ada` (access) and `daphne` (visual and wording). Each
slice deletes what it replaces, and vera confirms nothing was left
behind.

1. **Theme, Home, Trash.**
   - Builds `titleWithSuffix`, `ledgerDecoration`, the field call-site
     table, the dialog and snack bar themes, `SectionHeader`,
     `PortraitThumb`, `EmptyState`, `DateGroups`, the resume refresh and
     the tap-target spike.
   - Deletes `progress_pie_painter.dart`, the `CircleAvatar` in
     `memory_tile.dart:44`, the 72 inset, the full-screen spinners on
     these screens, and any per-site dialog or snack bar styling the
     theme now covers.
   - `MemoryTile` changes once, here. Re-check Merge, Places, quiz
     results and filtered practice.
   - Decide the app bar overflow for behaviour change 6.
2. **Person card, encounter edit, crop, merge picker.**
   - Builds the selected-row style and `BottomActionBar`.
   - Deletes `DetailListEditor.tintOf`, the ad-hoc headers and the
     outlines at `dictated_text_field.dart:160` and
     `detail_extras_editor.dart:301`.
   - Split the card off from the other three screens if the diff goes
     over about 1,500 lines.
3. **Quizzes, results, filtered practice, Timeline.**
4. **Places and the location picker.** Deletes the outline at
   `place_row.dart:280`.
5. **Settings, About, consent.** Deletes `settings_section.dart`.
6. **Capture, photo check, face picker, group details.** This slice goes
   last and needs a device walk:
   - from the shortcut to a saved photo, with gesture navigation;
   - landscape at 568 × 320 with no overflow;
   - cold start, from the shortcut to the camera preview, timed before
     and after **with a large library** (hundreds of records), because
     the shortcut builds Home first (`rememberem_app.dart:195-216`).
     The rule is no regression.

Before the last slice ships, Eric walks every page on a device in light
and dark mode.

## Out of scope

- No wording changes beyond the Strings table.
- No new features, no data or settings changes, no new permissions, no
  new packages.
- **Bulk purge ("Empty trash").** If it is wanted, it gets its own story
  with a counted dialog, a snapshot of the ids, and a message when it
  only partly succeeds.
- The website (`site/`), the launcher icon and the splash.

## Eric's decisions (2026-11-04)

1. **Person card photo:** 136 × 170, and a tap opens the full photo.
   Today it is 192 × 240; the canvas had 104 × 130.
2. **Timeline:** 44 × 55 thumbnails, with the first name underneath.
   The canvas had 38 × 48 with no names.
3. **Snack bars:** fixed, not floating.
