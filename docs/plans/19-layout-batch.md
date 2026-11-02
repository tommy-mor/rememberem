# 19. Layout batch: detail editing box, photo group, list, about

Sixteen small changes Eric asked for after using story 18 on his phone,
planned and checked together with a minimal crew. AC = acceptance criteria.

## 1–2, 8. Detail rows: collapsed line, expanded box

AC:
- Collapsed, a detail is one field whose label (kind and data) always sits
  on the border, for every kind (today an empty relationship's label sits
  inside). Its only button is an expander (no mic, no tune, no trash).
- Tapping the expander, or into the field, expands it. Expanded, the row is
  drawn inside one rectangle: the description with its mic, then the
  kind's extras indented below, then a trash button.
- Tapping outside the rectangle, or focus leaving it entirely, collapses it.
  A date picker, time picker, dropdown menu or map opened from inside the
  box does not collapse it (the person page is not the current route then).
- A new row opens expanded, as today.

Design: `DetailListEditor` keeps `_open`. Each expanded row is wrapped in
`TapRegion(onTapOutside)` and `Focus(onFocusChange)`, both collapsing only
while `ModalRoute.of(context)!.isCurrent`. `DictatedTextField` gains
`showMic` and an optional `trailing` widget (the expander) and
`alwaysFloatLabel`.

## 3. A happening's place from a map

AC: in an expanded happening, "Place" is a button showing the place (or
"Choose place") that opens the location picker. Tapping a known place's
pin chooses that place. "Use this spot" asks for a name, pre-filled with
the known place within the matching radius, if any. "Remote" sets the place
to Remote. The chosen point is kept with the detail so the map reopens
there.

Design:
- `Detail.location` (optional `GeoPoint`, new key `location`; no
  migration), set through `copyWith(location: () => …)`.
- `LocationPickerScreen` gets tappable known-place pins: a tap pops
  `LocationChoice.at(marker, place: name)`. `LocationChoice` gains an
  optional `place`.
- `PlaceNameDialog` (new) asks for the name for a spot.

## 4. Crop screen wording

AC: the crop page says "Use pinch to zoom in or out, then press Crop" at
the top and has one "Crop" button at the bottom. Only that button crops,
then returns to the person page. Back crops nothing.

## 5, 7, 9. The top of the person page

AC:
- The photo is on the left, with a crop icon button (no label) at its
  lower right.
- To its right, one group holds:
  - the Merge button, at 60 % of its font size;
  - below it, the date and time with the clock button;
  - below that, the coordinates (two decimal places) with the pin button.
- The rows in the group are spaced 40 % closer than today.
- The other pictures (not the newest) are listed just below the photo; the
  "Pictures" section at the bottom goes. Tapping the main photo opens its
  picture page, as the list entry did.

## 6. Tighter fields

AC: every text field has 30 % less inner padding. Design: the theme's
`InputDecorationTheme.contentPadding` is 70 % of Material's outlined
default (12, 20, 12, 12); detail rows use 70 % of the dense default.

## 10. A new location renames the place

AC: choosing a new location for a picture sets its Place to the known
place at that spot (within the matching radius, other encounters only), or
blank, which shows the hint "unknown". Remote still sets "Remote".

## 11–13. The person list

AC:
- The "Remembered" line is hidden until something is remembered.
- Each person shows a small number badge on the right with their memory
  points (face points plus detail points), only when above zero.
- The two text lines of a person are 50 % closer; people are 60 % closer.
- No trash button on the list. On the person page, a trash button sits just
  right of the name in the app bar. It saves, moves the person to the
  trash, returns to the previous page and shows "Moved … to trash" with
  Undo, which restores and reopens them.

Design: `MemoryTile` becomes a compact row of its own (not a `ListTile`)
with an optional badge; used everywhere a person is listed.

## 14. About page

AC: tapping the logo on the list, or "About Rememberem" at the bottom of
Settings, opens a page saying the app was created by Eric Jorgensen and
that suggestions are welcome, with links to https://ericjorgensen.com and
https://github.com/nebosite/rememberem/issues, opened in the browser.

Design: `AboutScreen`; links via `url_launcher` (pinned exactly) behind a
small `LinkOpener` interface so tests use a fake. Android manifest
`<queries>` gains VIEW https.

## 15–16. Timeline

AC: everything under a date on the timeline is indented. The word
"recorded" under pictures is gone.

## Tests

Detail box (expand by field tap, collapse on outside tap and not while a
picker is up, trash only when expanded, label floats); happening place
from a pin and from a named spot, with location kept; crop needs the Crop
button; group layout (merge, time, coordinates to the right of the photo,
two decimals); place reset on a new location (match and no match); list
badge, no trash, remembered hidden; trash from the page with Undo; about
links through the fake opener, from logo and Settings; timeline indent and
no "recorded".

## Out of scope

Coordinates on happenings for the Places page or the quiz; a colour or
size setting for badges.

## Review record

Minimal crew: Tess (Baseline) and Archie (Plan check). No factual dispute,
so no Vera at planning. Changes adopted:

- **No `Detail.location`** (Archie): a happening keeps only its place name.
  The map reopens at that place's pin (else here). Drops Tess's
  round-trip concern with it.
- **Keep `ListTile`** (Archie): `MemoryTile` is tuned (dense, compact
  density, little vertical padding) with an optional badge; only the list
  passes a badge. Trash keeps its Restore and Purge buttons. Tests that find
  "Move to trash" on the list move to the person page (Tess).
- **Pictures** (Archie): `PicturesSection` moves under the photo, without a
  heading, listing the other pictures; the main photo opens its own picture
  page through the same `_openPicture` (snackbar and cleanup unchanged).
- **Detail box** (Tess): the description field stays at the same place in
  the tree whether open or not, so it is never remounted. A row does not
  collapse while its dictation is listening (`DictatedTextField` reports
  listening). Tests: outside tap collapses; date picker, dropdown and map
  do not.
- **Trash from the page** (Tess): uses the merge path that keeps the
  snackbar; Undo restores, re-reads and opens a fresh page.
- **Place reset** (Tess): `LocationChoice.applyTo` takes the place finder.
  A real spot sets Place to the match or blank (hint "unknown"), whether the
  old place was typed or Remote. Tests: match, no match, Remote then spot.
- **url_launcher** pinned exactly at 6.3.3 (Archie).
- Declined: deleting `recordedIds` from the core timeline (Archie). It is
  tested and harmless; only the word goes from the screen.
