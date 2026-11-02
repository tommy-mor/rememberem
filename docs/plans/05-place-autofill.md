# Story 5: Place auto-fill

## Goal
When Fred takes a picture within 300 feet (91.44 m) of a place he has already named, the new person's Place field is already filled with that name when the notes screen opens. If several known places are in range, the closest wins. Fred's typing is never overwritten.

## Acceptance criteria
1. Capture within 91.44 m of an earlier encounter that has a location and a non-blank place opens the notes screen with Place showing that name.
2. With several places in range, the closest one is used, whatever the order of people on disk.
3. A place 91 m away counts; one 92 m away does not (the 91.44 m boundary itself is not tested, as it is unreachable in floating point).
4. No match, no GPS fix, or only blank-place neighbours: Place is blank, as today.
5. Places of trashed people are not used. Restoring a person makes their places usable again (holds by construction; covered by story 3's restore tests in trash_test.dart).
6. Every encounter of every active person counts, not just the newest.
7. A place Fred types or edits is saved as typed. Auto-fill happens only once, when the capture creates the record, never on load, save or merge.
8. A capture still creates exactly one person with one encounter and never loses the photo, even if place lookup fails (corrupt json, bad coordinates). Lookup failure gives a blank place.
9. Saved records keep the same JSON format. Legacy and story 4 files load unchanged.

## Design
Known places are derived at capture time from `repository.all()` (active only, so trashed are excluded). No new store, no format change, no cache that could go stale after merge, delete or story 9 edits.

Core (pure Dart):
- `packages/rememberem_core/lib/src/geo_point.dart`: add `double distanceTo(GeoPoint other)`, haversine, metres, Earth radius 6371008.8. Handles antimeridian naturally. Non-finite inputs give NaN.
- New `packages/rememberem_core/lib/src/place_finder.dart`: `PlaceFinder({double radiusMeters = 91.44})` with `Encounter? nearest(GeoPoint at, Iterable<Memory> active)`. Scans every encounter with non-null location and non-blank `place.trim()`. Keeps those with `distance <= radius`, written exactly that way (NaN never passes). Picks the smallest distance; ties broken by newest `capturedAt`, then story 4's final comparator key (`photoFileName`), so input order never matters. Returns the matched Encounter (story 6 reuses it); callers use `.place`. The returned name is used verbatim.
- `memory_repository.dart`: `add(...)` gains optional named `String place = ''`, written to the first encounter. One write, so there is no race with autosave (invariant 6). Update `json_file_memory_repository.dart` and `app/test/fakes/fake_memory_repository.dart` accordingly.
- `portrait_capture.dart`: `PortraitCapture` gains an optional `this.placeFinder = const PlaceFinder()` (const constructor), so `main.dart` and the three existing test call sites need no edit. If `location != null`, start `known = repository.all()` as a future at the beginning of `capture`, before face detection and the crop, through a small private async helper returning `Future<List<Memory>?>`: `try { return await repository.all(); } on Exception { return null; }`. Do not use an untyped `.catchError((_) => null, ...)` on a `Future<List<Memory>>`: its handler must return `FutureOr<List<Memory>>`, so returning null throws a type error at runtime (a typed `.then<List<Memory>?>((v) => v).catchError(...)` would also work). A corrupt json or purge race gives null; an `Error` is deliberately not swallowed, so programming bugs surface. The early future must never surface an unhandled rejection. Just before `add()`, inside the existing try/finally, `await known` and compute `place = list == null ? '' : finder.nearest(location, list)?.place ?? ''`, then `add(..., place: place)`. The `all()` read is read-only and not behind `_tail`, so starting it early is safe. The new record does not exist yet, so it cannot match itself. No cache.

UI: none. CaptureScreen already pushes the notes screen with the returned Memory, so Place is prefilled through the existing snapshot. No spinner; the lookup overlaps face detection and the crop (how much latency that hides is measured, see Risks).

Never-overwrite guard (AC7): structurally, `PlaceFinder` is called only inside `PortraitCapture.capture`, before `add`; load, save and merge never call it. The guarding test is that opening an existing person with a blank place does not fill it.

Privacy: no logging of coordinates; no new data stored beyond the place string already in the record.

## Tests
Core unit (`packages/rememberem_core/test/place_finder_test.dart`):
- Encounters at about 91.0 m and 92.0 m: the 91.0 m place is returned, the 92.0 m one gives null (fixtures built from metres north at lat 0 and a longitude case at lat 60).
- Places at 30 m and 60 m: the 30 m name is returned for both list orders.
- Equal distance: same name for both input orders (tie-break newest capturedAt, then photoFileName).
- Blank/whitespace place and null-location encounters are ignored even when closest: the farther real place wins.
- A non-latest encounter of a person is considered.
- A legacy single-record file (story 4 migration fixture) with place and location counts as a known place.
- `GeoPoint.distanceTo`: known pair (about 111.2 km per degree of latitude), zero for same point, one antimeridian pair is small (single assertion, no standalone fixture), NaN input gives NaN.
- NaN: a stored encounter with NaN coordinates as the only candidate gives null; a NaN capture location gives null.

Core capture (real temp dir, `portrait_capture_test.dart`):
- Existing record with 'Cafe' and location; capture 50 m away: saved `latest.place == 'Cafe'`.
- Capture with null location, blank-place neighbour, or trashed neighbour: place `''`.
- Repository whose `all()` throws an Exception: capture still saves one Memory, one encounter, blank place, photo file present.

Widget (fake repo, `app/test`):
- After capture, the notes screen shows 'Cafe' in Place; typing 'Cafe 2' then back saves 'Cafe 2' (cheap regression only, not the AC7 guard).
- Opening an existing person with a blank place does not fill it (the AC7 guard, with the structural fact above).

## Risks and mitigations
- Failed lookup after raw file deletion (baseline risks 1 and 2): try/catch to blank; tested.
- Wrong confident fill from a stray typo: Fred edits it on the notes screen; story 9 renames places. Accepted.
- Latency grows with the number of people (`all()` decodes every json). Acceptable at personal scale. Known places are derived on every capture with no cache, so story 9 edits to encounters are picked up and force no rework.
- Unmeasured latency: during the story 5 device check, time the awaited `known` future in `PortraitCapture.capture` with a Stopwatch on a profile build (no coordinates or names logged). Pass target: the await adds under 50 ms to shutter-to-notes at about 500 people. If it misses, move place derivation to a cached index.
- Flat-degree math errors: avoided with haversine and a longitude test.
- Per-encounter GPS exposure (baseline risk 10) is unchanged.

## Out of scope
Meeting auto-fill (6), a places store or editing (9), filtering and grouping (7, 8), per-file corrupt-record handling (risk 2), fuzzy or case-insensitive place matching, a user-set radius, a "filled automatically" indicator.

## Baseline record changes
- Map: capture fills the new encounter's place from the closest known place within 91.44 m, derived from active people's encounters.
- New invariant: auto-fill runs only at record creation, is best-effort (a lookup failure gives a blank place, never a lost photo), never overwrites typed text, and excludes trashed people. Tested: yes.
- Invariant 1 unchanged. Repository `add` takes an optional place. Core gains `PlaceFinder` and `GeoPoint.distanceTo`.
- Risk 1 note: lookup is guarded and adds no new loss path. Risk 2 note: a corrupt json makes the lookup blank, not the capture fail.

## Review record
Crews and agents: Vera (settlement), Archie (author), Tess, Rex, Pamala (guardians). No TieBreaker rulings (docs/reviews/rulings/ is empty); no stalemates.

Objections and settlements (all agreed):
1. Tess, NaN untested: added NaN tests for distanceTo and PlaceFinder; filter stays `d <= radius`.
2. Antimeridian weight: kept lat-60 longitude case and 91.0/92.0 m pair; antimeridian folded into a single distanceTo assertion.
3. Archie's amendments (catch only Exception, start `all()` early): already in plan, no change.
4. Pamala, typing test is not the AC7 guard: kept as regression; named the structural fact and the blank-place-open test as the guard.
5. Pamala, risk wording implied rework: reworded as latency note only.
6. Pamala, redundant restore test: dropped; AC5 sentence kept.
7. Pamala, unmeasured latency claim: softened, added Stopwatch device check with a 50 ms target at about 500 people.
8. Pamala, untyped catchError returns null: facts favour guardians; replaced with a private async try/on Exception helper.

Unverified: no builds, tests or devices run during planning; latency target unmeasured; Dart catchError behaviour taken from the settlement, to be confirmed by the 'all() throws' capture test.
