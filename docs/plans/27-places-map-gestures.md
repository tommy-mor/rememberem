# Story 27: radius slider on the label, select brings to front, double-tap zoom, long-press move

## What Eric asked

1. The radius slider is no longer at the bottom of the screen. It sits on
   the radius label that was tapped. Arrows and a pulsing background show
   that it slides. Tapping anywhere else ends sliding.
2. Selecting a place makes its tag the topmost on the map and centres the
   map on it.
3. Double-tapping a place on the map zooms so its radius is 20% of the
   visible map.
4. Long-pressing a place tag lets you move it to a different spot on the
   map.

## Design

### Radius slider on the label

- `RadiusSlider` is a new widget that replaces the row's radius button
  while sliding. It is a pill about 150 dp wide:
  - a ◀ chevron, the value ("555 ft") and a ▶ chevron;
  - a background that pulses gently (an AnimationController that repeats,
    stopped in tests by `disableAnimations`).
- A horizontal drag moves the position along `RadiusScale`: the full
  100 ft to 100 mi range is 300 dp of drag. It calls `onChanged` live and
  `onSettled` when the drag ends.
- Tapping a chevron steps by 1/40, as the panel's − and + did.
- `TapRegion(onTapOutside)` ends sliding.
- Semantics: a slider with a value, plus increase and decrease actions.
- `PlaceRow` takes `sliding`, `onChanged`, `onSettled` and `onDoneSliding`.
- `RadiusPanel` is deleted, and its "Use default" with it. To return to the
  default, Fred slides back to it; a radius equal to the default is stored
  as none (`withPlaceRadius` drops it). The map keeps the live circle and
  the "keep in view" behaviour (`StreetMap.focus`) as now.

### Select brings to front and centres

- `PlacesMap` puts the selected place's marker and circle last in their
  lists, so they draw on top. `StreetMap` already moves to `centre` when it
  changes.
- Selecting the place that is already selected centres the map again. A
  `centreTick` counter is part of the request, so it isn't ignored as
  "unchanged".

### Double-tap zoom

- `PlaceMarkerView` gets `onDoubleTap`. `StreetMap` takes
  `zoomTo: ({GeoPoint at, double meters, int tick})?`. A new tick fits the
  bounds of a circle 2.5 × the radius, with no padding, so the radius is
  20% of the map's shorter side (both the width and the height of a square
  fit).
- A double tap also selects the place.

### Long-press to move

- `PlaceMarkerView` gets `onLongPress`. It works on a named place; for an
  unknown place it shows a snackbar: "Name this place in the list first to
  move it."
- Moving mode, in `PlacesScreen`:
  - the map centres on the place;
  - a fixed pin is drawn over the map's centre;
  - a bar at the bottom of the map says "Drag the map to move Cafe", with
    Cancel and "Move here".
  - The place's own marker is hidden while moving.
  - "Move here" saves the map's centre as the place's spot.
- **Storage:** `AppSettings.placeSpots`, a map from a place's trimmed name
  to `{lat, lng}`, saved in settings.json. It is like `placeRadii`: adding
  the key needs no migration, damaged entries are dropped, and a rename
  carries it (`withPlaceRenamed`). Photos' own GPS is never changed, so a
  move can be undone and the original record stays true. The spot appears
  only in settings.json, on the device.
- `AppSettings.markerOf(PlaceGroup)` returns the spot for a named place
  that has one, otherwise `group.marker`. It is used by `PlacesMap` and
  `LocationPickerScreen`.
- `PlaceFinder` takes `spots` and measures a named place's encounters from
  its spot, so auto-fill matches where Fred put the place.

## Tests

- Core:
  - placeSpots round-trip, damage and rename;
  - markerOf;
  - PlaceFinder measuring from a spot.
- App:
  - tapping the radius shows the slider on the row;
  - a drag changes the circle live and saves on release;
  - a tap outside ends sliding;
  - chevrons step;
  - selecting puts that marker last and centres;
  - a double tap zooms (the camera fits about 2.5r);
  - a long press, then "Move here", saves the spot and moves the marker;
  - Cancel changes nothing;
  - an unknown place says to name it first.
- Updated: place_radius_test, which used RadiusPanel.

## As built (after Plan check and Gate)

- **Storage of a moved place.** The spot is passed into
  `PlaceBook.from(spots:)`, so `PlaceGroup.marker` returns it everywhere.
  There is no `markerOf`. `PlaceFinder` measures a moved place's
  encounters from the spot.
- **Unknown places.** They get no long press at all, so there is no
  snackbar.
- **Zoom.** It is its own request, `StreetMap.zoomTo` with a tick, fitted
  with no padding so the radius is exactly a fifth of the shorter side.
  Every double tap fits again.
- **While moving.** Selecting or zooming to another place is ignored.
  "Move here" without a drag keeps nothing. The mode stays until the save
  lands, and a rename ends it.
- **Accessibility.** Zoom and move are also screen-reader actions on each
  tag. The slider has increase and decrease actions and does not pulse
  when animations are off.
- **Accepted.**
  - A single tap on a map tag waits about 300 ms for a possible double
    tap.
  - A spot outlives a place no one is left at, as radii do.

