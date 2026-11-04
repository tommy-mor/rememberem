# Story 35: places list boxes, a notify box per place, an expander

## What Eric asked

1. "In the places list, put a box around the place name text and the radius
   text so it is clear they can be tapped and edited."
2. "Add a 'notify' checkbox just below the place name. If the box is
   checked then that place is considered for place notifications. All
   places are checked by default, except 'home', 'work' and 'church'."
3. (Added later) Lay out the row as follows:
   - the radius goes to the left of the notify checkbox, with the label
     "radius" after the value;
   - the notify checkbox is right-justified;
   - the summary text ("3 people · 4 Nov 2026") has an expander button on
     its left;
   - selecting a place no longer expands the people sublist. Only the
     expander does.

## Design

### Data (core)

- `AppSettings.placeNotify`: `Map<String, bool>`, keyed by trimmed name
  like `placeRadii`. It holds only Fred's choices; a missing key uses the
  default. A missing map reads as empty.
- `AppSettings.notifies(String place)`: the stored choice, or else true
  unless the name (trimmed, lower-cased) is `home`, `work` or `church`
  (`quietByDefault`).
- `withPlaceNotify(place, bool)` stores the choice. A rename carries it
  (in `withRenamedPlace`, beside the radius and spot).
- `PlaceFence.select` takes `bool Function(String) notifies`, and skips
  places that don't notify.
- `PlaceArrival` (the background handler) also checks `notifies`, so a
  fence registered before the box was unticked never shows.

### Row layout (`place_row.dart`)

```
[icon] ┌ Cafe on 5th ───────────────┐
       └────────────────────────────┘
       ┌ 555 ft radius ┐        Notify ☑
       └───────────────┘
       ▸ 3 people · 4 Nov 2026
```

- **The name** is an outlined `TextField` (`OutlineInputBorder`, dense).
  Editing works as now, with the check to save.
- **The second line** (named places only) has:
  - on the left, the radius as an outlined button (`OutlinedButton`,
    "555 ft radius"). It opens the slider in place as now, and the slider
    takes the button's spot.
  - on the right, `Notify` and a `Checkbox`, right-justified. Its
    semantics read "Notify on arrival at Cafe on 5th".
  - an unknown place has neither.
- **The third line** has an expander `IconButton` (`expand_more` /
  `expand_less`, "Show the people met at …") at the left, then the summary
  text.
- **Expansion** is per row and only by the expander, so several rows can
  be open (`PlacesScreen._expanded`, a set of keys). Selecting still
  highlights the row, draws the place on top and centres the map, but
  never expands it.
- `collapsedExtent` grows to fit three lines (about 136, scaled with the
  text). Scrolling to a selected row uses the sum of the heights above it,
  since expanded rows can now be above it.
  - Rows are laid out lazily, so the offset of the rows above is not
    known.
  - Instead, it uses `Scrollable.ensureVisible` on the row's context after
    a jump to an estimate (index × collapsedExtent + expanded rows above ×
    their measured height), corrected once it has been built.
- **Ticking or unticking** saves the choice (`settings.update`), then asks
  `PlaceNoticeKeeper` to sync, so fences follow at once. The box shows
  even while place notices are off (it is the place's choice), with the
  subtitle tooltip "Place notices are off in Settings" shown greyed.

## Tests

- **Core:**
  - the defaults (home, Work, CHURCH and " home " are quiet; others
    notify);
  - a stored choice wins;
  - JSON round-trip;
  - a missing map;
  - a rename carries it;
  - select skips quiet places;
  - arrival skips a quiet place.
- **App:**
  - the row shows the boxed name, "555 ft radius" and the Notify box;
  - ticking saves and syncs;
  - selecting doesn't expand;
  - the expander expands, and two rows can be open;
  - the slider still replaces the radius button.

## Amendments after Plan check (archie, marlin, gill)

- **`PlaceArrival.handle`** skips a quiet place with `continue` inside its
  loop over fence ids, so a later due fence still shows. A test covers it.
- **Scroll to selected:**
  - animate to the estimate, `index × collapsedExtent` plus, for each
    expanded row above, its people rows (each about 48 × the text scale);
  - then, once laid out, `Scrollable.ensureVisible` on the row's
    `GlobalObjectKey`, when its context exists;
  - the existing settle-once retry stays.
- **Quiet defaults kept as Eric asked:** home, work and church. Gill
  argued church and work should notify; that goes in the hand-over.
- **Notices off:** `PlaceNoticeKeeper.sync` with notices off clears the
  fences (it already handles that). A tick while off only saves the
  choice.

## As built (after Baseline; supersedes the above)

- **Core:**
  - `AppSettings.placeNotify` (JSON `placeNotify`, bad entries dropped),
    `notifies`, `withPlaceNotify`, `quietByDefault` and
    `notifiesByDefault`; a rename carries the choice.
  - `PlaceFence.select` requires `notifies`.
- **`PlaceArrival.handle`** skips a quiet place with `continue`. Accepted
  risk (rex): a damaged settings.json reads as defaults, so an unticked
  place could notify. Writes are temp-and-rename, so damage is rare, and
  the notice is secret on the lock screen.
- **The row:**
  - the name is boxed;
  - the radius is an outlined "555 ft radius" button, which the slider
    replaces;
  - "Notify" and its checkbox sit at the right;
  - an expander comes before the summary;
  - the selected row is tinted;
  - each row is keyed by a `GlobalKey` per place key, for `ensureVisible`.
- **Expansion** only by the expander (`_expanded`, several at once).
- **Scroll to selected:** an estimate, counting expanded rows above, then
  `Scrollable.ensureVisible`.
- **Notify ticks:** each awaits `settings.update`, then one keeper sync
  runs 1 s after the last tick (or at dispose if one is pending).
