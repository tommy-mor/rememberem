# Story 9: Places page with list and map

## Goal
Fred opens a Places page: the top half lists places by name ("unknown" when unnamed), the bottom half plots them on a map with labels. Tapping a marker or a row selects that place, centres the map on it, and expands the row to show the people met there. Fred can rename a place, or name an unknown one. Nothing leaves the device.

## Map: local canvas (settled)
The map is a no-basemap canvas plot (option c). This is settled by baseline invariant 12 (no app-originated network) and the private-by-default rule. Google Maps (a) and flutter_map with OSM tiles (b) would both send data off the device and break invariant 12; nobody argued for them. Cost: no streets, so less useful. A tile basemap is deferred and may only come later as an explicit, off-by-default opt-in decided by Eric. No map or http package is added. The builder does not wait on a ruling.

## Acceptance criteria
1. The home screen has an entry to the Places page.
2. The top half lists one row per place. Named places are grouped by trimmed, case-sensitive name (the same rule as `MeetingFinder.samePlace`). Located encounters with a blank place are grouped within 91.44 m and shown as "unknown". Unnamed, unlocated encounters appear in one "unknown" row with no marker.
3. Only active (non-trashed) people are listed, plotted or shown in expanded rows. Restoring a person makes them reappear on the next load.
4. The bottom half draws a labelled dot per place that has a location. One point, identical points and the antimeridian cause no NaN or crash.
5. Tapping a marker or a row selects that place (single selection), centres the map on it (selected dot mid-view, all dots still visible), expands only that row and scrolls it into view. The expanded row lists people's names ("Unnamed" if blank), with no photos or notes.
6. Rename: Fred can edit a place's name. Named place: every encounter whose trimmed place equals the old name gets the new name. Unknown cluster: only that cluster's encounters get it.
7. Blank or whitespace names are rejected with a message. "unknown" is never stored, so blank places stay blank and `PlaceFinder` still skips them.
8. Renaming to an existing name merges the two rows. The dialog warns about this before saving.
9. If a save fails, Fred sees an error, the list still shows the old name for the unsaved items, and nothing says "Saved". Retrying completes the rename with no duplicates or lost fields.
10. After a rename the list and map reload and show the new names.

## Design
**Data model:** no change. Places are derived, so there is no store and no JSON change; records already on disk load as before. Rename writes only `Encounter.place`, through `withPlace`.

**Core (pure Dart, `packages/rememberem_core/lib/src/`, exported from `rememberem_core.dart`)**
- `place_group.dart`: `PlaceGroup { String? name; List<(Memory, Encounter)> members; GeoPoint? marker }` (a Dart record, no separate member class). `label` is `name` or "unknown". `marker` is the newest located member's location.
- `place_book.dart`: `PlaceBook.from(List<Memory> active)` builds the groups. Named: key is `place.trim()`. Unnamed: sort located encounters with `Encounter.newestFirst`, then join each to the first group whose anchor (its first, newest member) is within 91.44 m via `GeoPoint.distanceTo`, else start a new group. Anchoring rather than chaining stops unbounded growth and makes the result independent of input order. Unlocated unnamed encounters go to one extra group. Groups are sorted by label, then newest member. People are deduplicated by memory id within a group. An unnamed cluster is not a stable identity: membership shifts as newer encounters arrive, so a rename targets the exact member set captured at tap time.
- `place_renamer.dart`: `PlaceRenamer(MemoryRepository)` with `Future<void> rename(PlaceGroup group, String newName)`. It throws `ArgumentError` if `newName.trim()` is empty. Before writing it re-reads `all()` and `trashed()` and applies changes to the fresh `Memory`, never to the page-load copy (`save` overwrites the whole record, so a stale copy would clobber newer edits). For an unnamed group the target set is the group's exact members, identified by memory id plus the encounter's `photoFileName`, and is never recomputed. For a named group it is every encounter in `all()` and `trashed()` whose trimmed place equals the name. Including trashed people is a constraint (a later restore must not bring back a split name); `save` re-applies the on-disk `trashedAt`, so a rename cannot untrash. It saves each affected memory serially, once, with all its matching encounters changed together. It skips ids that vanish between its re-read and its save (the `StateError` that `_update` throws for a purged id is caught for that id only; other errors propagate unswallowed). It is idempotent. `withPlace` preserves `photoFileName`, `capturedAt`, `location` and `meeting`.

**App (`app/lib/src/places/`, one class per file)**
- `places_screen.dart`: a `Column` of `Expanded(PlaceList)` and `Expanded(PlacesMap)`. It holds the selected-group state shared by both halves and reloads on `didPopNext`, following the `memory_list_screen` pattern. The home screen gets a Places entry that opens it.
- `place_list.dart` and `place_row.dart`: `ListView` of `ExpansionTile` rows, open only when selected, with a rename button. Each row shows a subtitle (people count and newest date) so several "unknown" rows can be told apart. One named constant defines the collapsed row extent, and the row is forced to that extent (`ConstrainedBox`/`SizedBox`) so scroll maths and layout cannot drift. Scrolling to the selection uses a `ScrollController` and `animateTo(index * extent)`; this is exact only because single selection means only the selected row is expanded. `ensureVisible` is not used because it does nothing for unbuilt lazy rows.
- `places_map.dart`, `place_map_painter.dart`, `place_map_projection.dart`: `CustomPaint` with an equirectangular projection into the bounding box, longitude scaled by cos(latitude) (clamped away from zero), a minimum span when the span is zero, and padding. Centring without zoom: the projection is built around the selected point as the view centre, with the half-span set to the largest offset from it to any dot, so the selected dot sits mid-view and every other dot stays visible; with no selection it fits the bounding box. The selected dot is also drawn larger with a ring. The pure projection class has `project`, `centreOn` and `hitTest` (nearest dot within 24 px, ties broken by label order).
- `rename_place_dialog.dart`: text field, a merge warning when the name matches another group, and the number of people affected (active and trashed) so the writes to hidden trashed people are visible.
- Errors show a fixed snackbar message, never raw exception text (baseline risk 14).

## Tests
- `place_book_test.dart`: ' Cafe' and 'Cafe ' merge while 'cafe' stays separate; shuffled input gives identical groups; an A-B-C chain with A and C over 91.44 m apart gives two groups; unlocated blank encounters go to an "unknown" group with null marker; a trashed memory never appears; a merged person (several photos) appears once per group (dedupe by memory id).
- `place_renamer_test.dart` (fake and real `JsonFileMemoryRepository`): 'Cafe' to 'Diner' changes every active and trashed trim-equal encounter; other places, trash state, `photoFileName`, `capturedAt`, `location` and `meeting` are unchanged; a reload from disk matches. Multi-encounter case: one Memory with three encounters (Cafe, Park, blank) plus a second blank cluster beyond 91.44 m; rename Cafe, then rename one unknown cluster, and assert only the targeted encounters changed and `photoFileName`, `capturedAt`, `location`, `meeting` are identical on all. Renaming an unknown cluster leaves other blank encounters blank. A blank name throws and changes nothing. A fake that throws on the second save surfaces the error with the first save kept, and re-running finishes with no duplicates; a variant where the failing save is a trashed memory. An id purged between re-read and save is skipped without failing the rest.
- `place_map_projection_test.dart`: one point, identical points and the antimeridian give finite values; `hitTest` picks the right dot; `centreOn` puts the point mid-view with every dot inside the view.
- `places_screen_test.dart` (widget):
  - The list shows names and "unknown"; tapping a marker and tapping a row each expand exactly that row with the right names; a null-location group is listed without a marker; a failing-save fake shows the error and the old name.
  - Home screen shows a Places entry that opens `PlacesScreen`.
  - After a successful rename, the list and map show the new name.
  - A trashed person restored in a fake repository shows in the expanded row once the route re-appears (`didPopNext`).
  - With 30+ places, tapping the last marker leaves its row on screen; a row tap after another row was expanded scrolls correctly; the same at a large text scale.
  - Smoke check with a few hundred places that the list stays lazy (not all rows built).
- After implementing, run the app and open the page on a device or emulator, not just the tests.

## Risks and mitigations
- Map privacy: the canvas choice above. The page puts people's names and GPS dots together, so names appear only on expand, no photos, no logging (baseline risks 10 and 16).
- Partial rename without a transaction: serial, idempotent saves, a visible error and a retry.
- Renaming to an existing name merges two places: warned about and tested.
- Overlapping markers: nearest-dot rule with a deterministic tie-break; the list is the fallback.
- Roadmap: grouping lives in core, not in a widget, so stories 10 to 14 can reuse it. Story 13 needs an ordinary route; the rename is awaited before the dialog closes, so no flush is pending.

## Out of scope
Tile or street maps (a basemap may only come later as an explicit, off-by-default opt-in decided by Eric), geocoding, deleting or splitting places, editing a person from this page, pinch zoom, name-similarity clustering, any persisted place store.

## Baseline record changes
- Map: add the Places page (list plus local canvas map, derived from encounters, rename via `PlaceRenamer`).
- Invariant 12 stays true: still no app network client and no map package.
- New invariants: place identity is the trimmed exact name (and 91.44 m anchoring for blank names); "unknown" is a label only, never stored; rename covers active and trashed people and preserves all other fields.
- Open risks: add that rename has no transaction (mitigated by idempotency). Update risk 10: GPS is now also plotted.

## Review record
**Crews and agents:** guardians Archie, Tess, Sally and Grace; Pamala (challenger); Vera (settler); this neutral plan editor. No TieBreaker was run.

**Objections and settlement (all settled by Vera, no stalemates):**
1. Should rename include trashed people? Agreed: kept as a constraint. Added skipping of ids purged between re-read and save, and a trashed-save-failure test. Pamala withdrew her Consider ranking; Grace's conditional was not triggered.
2. Is the map choice a stalemate? Agreed: no. Section retitled "Map: local canvas (settled)", hedge removed; basemap deferred to an Eric-decided opt-in.
3. Scroll-to-selected untested, fixed extent may drift: guardians favoured. Named extent constant enforced on the row; multi-screen, large-text and lazy-list tests added.
4. Renamer tests used only one-encounter people: guardians favoured. Multi-encounter and merged-person tests added.
5. Criteria 1, 3, 10 untested: guardians favoured. Home entry, post-rename reload and restore-via-`didPopNext` widget tests added.

**Rulings:** none (docs/reviews/rulings/ precedent consulted; no new ruling issued for this story).

**Unverified:** no builds, tests or devices were run during planning. The behaviour of `_update`'s `StateError` and `save` trash handling is cited from review evidence (`json_file_memory_repository.dart:50-53, 69, 193-197`), not re-read here. Real-text-scale row height is assumed to fit the forced extent; confirm on a device. Stories 7 and 8 files (`MemoryFilter`, `TimelineBuilder`) were not checked for overlap with the home screen entry.
