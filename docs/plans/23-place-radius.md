# Story 23: a radius for each place

Eric: "Optional custom radius for places. Whenever showing places on a map,
show the radius as a circle under the location tag on the map. Show the
value of the radius by the place name in the list. Remove the edit button
for places. Instead let me edit the name on the place list itself. If I am
changing a known place name, ask for confirmation. Clicking the radius value
should superimpose a slider bar for adjusting the place radius. The slider
should be logarithmic, smoothly sliding from 100 feet to 100 miles. The
circle showing the radius on the map should update realtime as the slider
is moved. Add an option in settings to use m/km instead of feet/miles.
Default to m/km in countries that are metric."

## Behaviour

- **Radius per place.** Each named place has a radius: its own if Fred has
  set one, else Settings > Matching > "Same place within" (as today).
  Unknown (unnamed) places have no name to keep a radius under, so they get
  no radius control and no circle.
- **Matching uses it.** A new photo takes the name of the nearest known
  place whose own radius reaches it. This covers capture, the location
  picker and a happening's place.
- **Circles.** Every map that shows places (the Places page and the
  location picker) draws each named place's radius as a translucent circle
  under its pin.
- **The list:**
  - Each row shows the name as an editable field. The edit button is gone.
  - The radius sits beside the name ("560 ft", "1.2 mi", or "170 m",
    "1.5 km").
  - Tapping the row elsewhere selects it, as today.
- **Editing a name.** On submit or focus leaving:
  - blank or unchanged: the field goes back to the old name;
  - an unknown place: renamed at once;
  - a known place: a confirmation dialog says "Rename "Park" to "City
    Park"?", how many people it changes, and whether it merges with another
    place. Cancel puts the old name back.
  - A renamed place keeps its custom radius. When it merges into a place
    that has its own radius, the merged place keeps that one.
- **The slider:**
  - Tapping the radius selects the place and lays a panel over the top of
    the map. The panel holds the place name, the value, a logarithmic
    slider from 100 ft (30.48 m) to 100 mi (160.9344 km), "Use default"
    and "Done".
  - Sliding redraws the circle every frame, and the map zooms to keep the
    circle in view.
  - The value is saved when the slide ends. "Use default" removes the
    custom radius.
- **Units.** A new Settings > Maps switch, "Metric units (m, km)", changes
  every distance shown, the "Same place within" stepper included. It is
  stored as a value only once Fred touches the switch. Until then it
  follows the phone's region: feet and miles in the US, Liberia, Myanmar
  and the UK, metric everywhere else.

## Data

`settings.json` (`AppSettings`) gains two optional keys, so no migration is
needed:

- `placeRadii`: a map from a place's trimmed name (case kept, as
  `MeetingFinder.samePlace` compares names) to metres. Bad entries are
  dropped, and values are clamped to the slider's range.
- `metricUnits`: true or false. When missing, it follows the region.

## How

- **Core:**
  - `AppSettings.placeRadii`, `metricUnits`, `radiusFor(name)`,
    `withPlaceRadius(name, metres?)` and `withPlaceRenamed(old, new)`.
  - `PlaceFinder(radiusMeters, radii)` checks each encounter against its
    place's radius.
  - `RadiusScale`: the log mapping between slider position (0–1) and
    metres.
  - `Distance.format(metres, metric)`: rounded text.
  - `AppSettings.metricByDefault(countryCode)`.
- **App:**
  - `StreetMap` gains `circles` (drawn under markers) and an optional
    `focus` (centre and radius) that fits the camera to that circle.
  - `PlacesMap` and `LocationPickerScreen` pass circles.
  - `PlaceRow` gets an inline name field and a radius button.
  - `PlacesScreen` holds the slider panel state and the rename
    confirmation.
  - `RenamePlaceDialog` becomes a confirmation, `ConfirmRenameDialog`.
  - A metric switch in Settings.

## Tests

- **Core:**
  - the log scale's ends, midpoint and round trip;
  - distance formatting in both units;
  - the country default;
  - `placeRadii` reading damaged values;
  - renaming moves a radius, and a merge keeps the target's;
  - `PlaceFinder` respects a big and a small custom radius.
- **App:**
  - a row shows its radius in both units;
  - renaming an unknown place happens without asking;
  - renaming a known place asks, and Cancel restores the name;
  - tapping the radius shows the slider, and sliding changes the map
    circle's radius live and saves on release;
  - Use default clears the custom radius;
  - the location picker draws circles;
  - the Settings switch.

## Plan check amendments (`archie`, `ada`)

- **Keys:** radii are keyed by trimmed name, case kept, which matches
  `PlaceBook` and `PlaceRenamer`.
- **Rename:** the radius moves (`withPlaceRenamed`) only after
  `PlaceRenamer.rename` succeeds. A radius left behind by a failure, or by
  a place's last person being purged, is ignored.
- **Callers:** `AppSettings.placeFinder` passes the radii, so its callers
  (`capture_screen.dart`, `location_picker_screen.dart`,
  `memory_edit_screen.dart`) don't change. Unnamed clusters on the Places
  page keep the default radius.
- **Equality:** `AppSettings` `==` and `hashCode` compare the radius map.
- **Camera:** while sliding, the map refits only when the circle spills out
  of view. On release it refits once.
- **Rows** grow with text size (a minimum of 72 dp, not a fixed height).
  The scroll offset is estimated with the text scale and then corrected,
  as now.
- **Slider access:**
  - TalkBack reads the formatted distance (`semanticFormatterCallback`).
  - − and + buttons step the slider as an alternative to dragging.
  - The radius button is at least 48 dp and is labelled "Radius of Park:
    560 ft. Adjust".
- **Names:**
  - Committed only on the keyboard's Done or a ✓ button, which shows while
    the text differs. Leaving the field puts the old name back, so a stray
    tap never starts a rename.
  - Tapping the name field also selects the row.
- **Panel:** sits at the bottom of the map, within thumb reach. Circles have
  an outline as well as a fill.
