# Story 7: Matching mode (filter people)

## Goal
Fred opens matching mode from the main list and filters active people by place, meeting name, date and details text. Everyone who matches is listed, and tapping one opens that person's details page. Read-only; no storage change.

## Acceptance criteria
1. The main list app bar has a "Match people" (search icon) action, next to Trash. It opens the Matching screen.
2. With no filter set, the screen lists all active people, newest first. Trashed people never appear.
3. Place and Meeting are pickers offering the distinct known values (trimmed, de-duplicated, sorted case-insensitively, blank values omitted) from every encounter of every active person. A "Any" choice clears the picker.
4. A person matches a place or meeting filter if ANY of their encounters has that place or meeting (compared with `MeetingFinder.samePlace`, trim-equality, case-sensitive). A person met at "Cafe" then "Park" shows under "Cafe".
5. Date (tested through MemoryFilter only, no date-picker widget test) is chosen with a date picker and clears with a clear button. It matches if ANY encounter's capture day, in local calendar time, is that day. A 23:30 local capture matches that day, not the next.
6. Details contains is a text field. Case-insensitive substring over detail texts only. The name is not searched. Blank or whitespace-only text means no filter.
7. Filters combine with AND, and all must be satisfied by the same person (place and meeting may be satisfied by different encounters; see Risks). Unset filters are ignored.
8. Results update as filters change. A count ("3 people") shows, and a "No one matches" message shows when empty.
9. Each result is a MemoryTile (photo, name, place and meeting of the latest encounter). No matching detail text is shown. Tapping opens the existing MemoryEditScreen. Back returns to Matching with the filters kept and results re-queried, so an edit, trash or merge is reflected.
10. If loading fails, an error message with Retry shows, never an endless spinner.
11. Nothing is written or persisted, including filter state. Leaving the screen resets filters.

## Design
Data model: none. No JSON change, so all records on disk, legacy single-photo ones included, work unchanged via `Memory.fromJson`.

Core (pure Dart, `packages/rememberem_core/lib/src/`, exported from `rememberem_core.dart`):
- `memory_filter.dart`: `class MemoryFilter { const MemoryFilter({String? place, String? meeting, DateTime? day, String detailsContains = ''}); bool get isEmpty; bool matches(Memory m); List<Memory> apply(List<Memory> all); static List<String> places(List<Memory>); static List<String> meetings(List<Memory>) }`.
  - Place and meeting use `MeetingFinder.samePlace(encounter.place, filterValue)` over `m.encounters`. This depends on stories 5-6 having landed; samePlace is trim-equality and case-sensitive (per the stories 5-6 rule), and the picker de-duplicates with the same function so picker and filter cannot disagree. If it has not landed when this is built, use a private trim-equality in MemoryFilter and swap it later. Blank filter strings are treated as null.
  - Day: the picked `DateTime` and each `encounter.capturedAt` are compared by `toLocal()` year/month/day, via a private helper in this file. No shared CalendarDay class until story 8 actually needs it (YAGNI; extraction is trivial then). Detail.at is UTC and Encounter.capturedAt may be either, so both go through `toLocal()`.
  - Details: `m.details.any((d) => d.text.toLowerCase().contains(needle))` with a trimmed, lowercased needle.
  - `places` / `meetings`: gather trimmed non-empty encounter values, de-duplicate with samePlace semantics (first spelling wins), sort case-insensitively.
No repository change; callers use `repository.all()` only (never `trashed()`).

App (`app/lib/src/memories/`):
- `matching_screen.dart`: `MatchingScreen({required services, required routeObserver})`, like MemoryListScreen; the repository and dictation come from `services.repository` and `services.dictation`. It mixes in RouteAware, calls `all()` in initState and in `didPopNext` with the reload-generation guard (copy the `_reloadGen` pattern), and holds `MemoryFilter` state in the widget. A load error sets `_error` and shows Retry. The filter controls (two dropdowns, a date button with clear, a text field labelled "Details contain") are built inline in this screen; extract a widget only if the file grows large (about 250 lines).
- `memory_list_screen.dart`: add the AppBar action (hide any snackbar first, as `_openTrash` does) and push MatchingScreen with `services` and `routeObserver`. The list screen's own reload on didPopNext stays.
Results use `MemoryTile(memory: m, photo: services.repository.photoFile(m), onTap: ...)`, and onTap pushes MemoryEditScreen exactly as the list screen's `_open` does (same arguments).
Pickers are `DropdownButton<String?>` with a null "Any" item. Items are the known values plus the current selection if it is no longer among them, so a value removed by an edit or trash does not trip Flutter's value-must-match-an-item assertion. The filter is kept and still applies.

## Tests
Core:
- `memory_filter_test`: encounters [Cafe (older), Park (newest)] with place "Cafe" matches (fails under latest-only).
- Same file: a person with place "Cafe " matches a filter of "Cafe" (trim rule); empty or whitespace filters return everyone.
- Same file: place A plus details "chess" returns only the person with both. Blank details text is ignored. The name alone does not satisfy a details filter.
- Same file: capturedAt at local 23:30 on D matches D and not D+1. Times are built from local parts so the test is independent of machine time zone.
- Same file: `places` over "Cafe", "Cafe " and blank gives one entry "Cafe", sorted.
App (widget, fake repository):
- Matching screen lists active people only. A trashed person is absent.
- Choosing a place narrows the list and the count text updates.
- Tapping a result opens MemoryEditScreen for that id. After the name is changed and the screen popped, the result shows the new name (re-query).
- Place selected, then the last person with that place is edited away and the screen reloads: no dropdown assertion, filter still applied and the old value still shown.
- A repository whose `all()` throws shows the error and Retry, and Retry loads the list.
- List screen: the "Match people" action pushes MatchingScreen.
Run all tests after the build, and launch the app (or an integration test) to open Matching once on a device.

## Risks and mitigations
- Latest-only matching hides multi-meeting people: always iterate `encounters`.
- Place and meeting are tested independently, so a person who met "Cafe" once and "Weekly club" at another place matches both. Accepted for now; same-encounter matching is a later refinement if Fred asks.
- Date off-by-one: one private local-day comparison using toLocal(). A time zone change after capture shifts old days; accepted.
- Stale results: re-query on didPopNext. The edit screen's unawaited dispose flush (baseline risk 20) can race the reload; same exposure as the main list.
- Corrupt record makes all() throw (baseline risk 2): handled here with an error state, though the root cause stays open.
- Privacy: no persisted query, no detail snippets in results.
- Name search deliberately excluded; revisit only if Eric asks.

## Out of scope
Timeline (8), Places page and map (9), games, metric, reminders, back-navigation overhaul (13), persisting filters, searching trash, sorting options, name search, highlighting matched text, multi-select.

## Baseline record changes
- Map: add "Matching: MatchingScreen filters active people by place, meeting, date (local day) and details text, any-encounter, AND."
- Remove "search" from the Absent list.
- Add invariants: matching is read-only and uses all() only; place, meeting and day are tested against every encounter; day comparison is local via toLocal(). Tested: yes.
- Risk 2 note: Matching shows an error state, the main list still spins.

## Review record
Crews and agents: the planning crew (plan author), tess (test critic), archie and marlin (challengers), and Vera (settlement). This editor applied the settlement. Rulings: none were issued, so docs/reviews/rulings/ was not consulted for new precedent.

Objections and settlement:
1. Archie vs tess, date-picker and Retry widget tests are heavy. Settled: agreed. Tess dropped the date-picker widget test (AC5 tests dates through MemoryFilter only; a core test covers the 23:30 local case). The Retry widget test stays as the only coverage of AC10. Plan change: none (already in the plan).
2. Marlin vs tess, "name alone does not satisfy a details filter" is invisible behaviour. Settled: agreed. Marlin withdrew. It stays as one assertion inside the "place A plus details chess" core test, with no new file or fixture. Plan change: none.
3. Archie vs tess, offer the AC6 name-exclusion to Eric as a decision. Settled: agreed. Archie withdrew. It is a product rule and flipping it costs one line. The plan flags "revisit only if Eric asks". If Eric picks the other rule, the assertion must be rewritten before the build. Plan change: none.

Stalemates: none. Rulings: none (no TieBreaker files).

Unverified: nothing was built or run during planning. The dependency on MeetingFinder.samePlace from stories 5-6 is assumed (fallback: private trim-equality in MemoryFilter). Widget-level behaviour (dropdown assertion handling, didPopNext reload) is untested until the build.
