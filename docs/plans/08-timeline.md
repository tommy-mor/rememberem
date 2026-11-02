# Story 8: Timeline mode

## Goal
Fred opens timeline mode from the main list. It shows every detail date (a local calendar day, no times) with miniature photos of the active people who have a detail on that day, grouped by place + meeting. Tapping a date shows just that day's people, grouped the same way. Tapping a person opens their card. Read-only; no storage change.

## Acceptance criteria
1. The list app bar has a "Timeline" action next to "Match people". It opens the Timeline screen.
2. Days are listed newest first. Each day has a date header (no time) and, under it, groups headed "Place - Meeting" (either half may be missing; both blank shows "Unknown place"). Each group shows miniature photos with first names or "Unnamed".
3. A person appears once per (day, group), however many details they have that day.
4. A detail is placed in the group of the person's encounter on the same local day nearest in time to the detail. A tie goes to the newer encounter (Encounter.newestFirst order). If no encounter is on that day, the latest encounter is used. A person can therefore appear in two groups on one day.
5. A person with no details appears once, dated at their first (oldest) encounter's capture day, in that encounter's group. This "recorded" entry is shown with a "recorded" caption on the miniature.
6. Groups with the same place and meeting after trimming merge ("Cafe" and "Cafe " are one group), using MeetingFinder.samePlace semantics.
7. Miniatures use the newest photo. Trashed people never appear.
8. Tapping a date header opens the same screen restricted to that day. Back returns to the full timeline.
9. Tapping a miniature opens MemoryEditScreen for that person. On return, the timeline reflects edits, trash and merges.
10. An empty app shows "No one yet". A load failure shows an error with Retry, never an endless spinner.
11. A 23:30 local detail is on that day, not the next, in any time zone.
12. Nothing is written, including the "recorded" stand-in.

## Pre-check before building
Stories 5-7 are not in the tree at 34a2152. Before the build, confirm `MeetingFinder.samePlace` is public, exported and trim-equality (case-sensitive), and see what MemoryFilter's private local-day helper and MatchingScreen look like. If any has not landed, use a private trim-equality in the builder and swap later, as plan 07 does.

## Build order
1. Extract `LocalDay`, run `memory_filter_test`. 2. `TimelineBuilder` and its core tests. 3. Screen, miniature and list action.

## Design
Data model: none. No JSON change; legacy records work through `Memory.fromJson`. "recorded" is computed and never added to `Memory.details` (merge unions details by id, so a persisted fake would duplicate).

Core (`packages/rememberem_core/lib/src/`, exported):
- `local_day.dart`: `class LocalDay implements Comparable<LocalDay>` with `LocalDay.of(DateTime)` (calls `toLocal()`, keeps y/m/d), `==`, `hashCode`, `compareTo`, `toDate()`. Extracted from MemoryFilter's private helper; MemoryFilter now uses `LocalDay.of(a) == LocalDay.of(b)`. The only constraint is that `memory_filter_test` passes after MemoryFilter uses `LocalDay`. If story 7 is absent, the builder keeps a private trim-equality fallback.
- `timeline_group.dart`: `class TimelineGroup { final String place; final String meeting; final List<Memory> people; final Set<String> recordedIds; }` (trimmed strings; the people are distinct by id and sorted by first name case-insensitively, then id; `recordedIds` holds the ids shown with the "recorded" stand-in, so the screen can caption them). No exported entry class: the builder uses a private record `(Memory, Encounter, bool recorded)` internally.
- `timeline_day.dart`: `class TimelineDay { final LocalDay day; final List<TimelineGroup> groups; }`.
- `timeline_builder.dart`: `class TimelineBuilder { List<TimelineDay> build(List<Memory> active, {LocalDay? only}) }`. For each memory: if details are empty, make one recorded entry from `encounters.last` (the oldest) at `capturedAt`. Otherwise, per detail, find the encounter via the rule in AC4. The comparison is `|detail.at - capturedAt|` on same-day candidates, tie-broken by `Encounter.newestFirst`. Bucket by (`LocalDay.of(detail.at)`, trimmed place, trimmed meeting), where equality uses `MeetingFinder.samePlace` on each half (never a joined string). Dedupe by memory id per bucket. Days are sorted descending. Groups are sorted by place then meeting, case-insensitive, then by the exact trimmed strings as a final tie-break, with "Unknown place" last. Merge is by `samePlace` (trim equality, case-sensitive), so "cafe" and "Cafe" stay separate adjacent groups; this is stated and tested, not accidental. Input order never changes the output (people are sorted explicitly as above). It never mutates a Memory.

App (`app/lib/src/memories/`):
- `timeline_screen.dart`: `TimelineScreen({required services, required routeObserver, LocalDay? day})`. It follows MatchingScreen: RouteAware, `all()` in initState and didPopNext, a `_reloadGen` guard, `_error` with Retry. It builds a lazy `ListView.builder` over days (or one day when `day` is set). A date header uses `InkWell`, which pushes `TimelineScreen(day: ...)`.
- `timeline_miniature.dart`: a small widget (Image.file of `repository.photoFile(m)` with `cacheWidth` about 160, name caption, optional "recorded" caption). It takes an `onOpen` callback; the screen's open-person helper pushes MemoryEditScreen exactly as the list's `_open` does (same parameters, snackbar hidden). Miniatures within a day are laid out in a `Wrap`, so a day with 100+ people decodes them all, bounded by `cacheWidth`; accepted.
- `memory_list_screen.dart`: add the AppBar action (hide any snackbar first, like `_openTrash`).
No dependency on maps or a Places model. Group keys stay plain trimmed strings so story 9 and the games can reuse them.

## Tests
Core `timeline_builder_test` (all times built from local parts):
- Encounters Cafe on D and Park on D+3 (newest); a detail on D lands under D/Cafe. Fails under latest-only.
- `LocalDay.of` gives the same day for a UTC-stored and a local `capturedAt`. People in a group are sorted by first name then id for shuffled input. "cafe" and "Cafe" stay separate groups.
- Two same-day encounters: the nearer one wins; an exact tie gives the newer one; the result is the same for reversed input order.
- A detail on a day with no encounter uses the latest encounter. Blank place and meeting give "Unknown place".
- "Cafe" and "Cafe " merge into one group. Three details on one day in one bucket give one person and unchanged `memory.details.length`.
- A person with no details gives one recorded entry on the first encounter's local day, and no entry for a person with details.
- Detail at local 23:30 on D and 00:30 on D+1 give two days. `only:` limits output to one day.
- `local_day_test`: the 23:30 case; `memory_filter_test` passes after MemoryFilter switches to `LocalDay.of(a) == LocalDay.of(b)`.
App `timeline_screen_test` (fake repository), three cases only; grouping, sorting and day filtering are tested in core:
- Renders days and group headings; a trashed person is absent. AC12 assertion: after load, and after a no-details person renders with "recorded", `FakeMemoryRepository.saves`, `purges`, `merges` and `deletedPhotos` are all empty and the stored person's `details.length` is unchanged (the fake has no add/trash/restore counters; assert on these four lists or add small counters to the fake). Do not assert `saves` is empty in the rename-and-pop case below, since MemoryEditScreen saves a rename; use a separate open-and-pop-without-edit case, or assert only before the tap.
- Tapping a miniature opens MemoryEditScreen for that id; after a rename and pop the new name shows.
- An `all()` that throws shows Retry; Retry loads.
Run the core and app tests after the build, then launch the app and open the timeline once.

## Risks and mitigations
- The mapping rule is a product guess. A detail re-dated to a day with no encounter falls back to the latest encounter's place; "Unknown place" might be more honest. It is a product choice isolated in one function; AC4 stays as written. Flag it to Eric at review.
- Duplicate faces: dedupe per bucket. A person with two encounters on one day, with different details, can appear twice by design.
- Stale data (baseline risk 20): re-query on didPopNext with the generation guard.
- Corrupt record (risk 2): error state here; root cause stays open.
- Performance: day widgets are lazy (`ListView.builder`) and images use `cacheWidth`, but `TimelineBuilder.build()` runs over all memories and details on every load and didPopNext. Cost is O(details); accepted.
- Privacy: see baseline risk 16 (no new mitigation).
- Time-zone change after capture shifts old days; accepted, as in story 7.

## Out of scope
Places page and map (9), games, metric, back-navigation overhaul (13), reminders, zoom or scrolling to a date, search within the timeline, persisted view state, detail text on miniatures, trash in the timeline.

## Baseline record changes
- Map: add "Timeline: TimelineScreen lists local days newest first, with active people grouped by place + meeting; tapping a date narrows to that day."
- Invariants: timeline is read-only and uses all() only; a detail maps to the nearest same-day encounter (tie newer), else the latest, else "Unknown place"; "recorded" is computed, never persisted, dated at the first capture; local days come from one shared `LocalDay` used by MemoryFilter and TimelineBuilder. Tested: yes.
- Risk 2 note: Matching and Timeline show an error state; the main list's load handling is unchanged (verify when building).

## Review record
- Crews and agents: plan author, plus reviewers Tess (tests), Gill (guardian), Archie (architecture), with Vera settling disputes. Neutral plan editor applied the settlement. No TieBreaker was needed.
- Objections and settlement:
  1. Tess: AC12 read-only invariant had no test assertion. Agreed. The "Renders days and group headings" app test now asserts saves, purges, merges and deletedPhotos are empty and details.length is unchanged; the rename-and-pop case is excluded from the saves assertion.
  2. Gill/Tess (challenge 6): "MemoryFilter unchanged / memory_filter_test untouched" was stale and unverifiable (git ls-files shows no memory_filter or matching file; meeting_finder.dart is untracked). Agreed. Reworded to: memory_filter_test passes after MemoryFilter uses LocalDay; the private trim-equality fallback stays for when story 7 is absent.
  3. Archie (challenge 2): the risk 16 line was noise. Agreed. Shortened to a pointer to baseline risk 16.
  4. Gill (challenge 5): the latest-encounter fallback for a re-dated detail may be wrong. Agreed to no change; AC4 stays. A product question for Eric, isolated in one function.
- Stalemates: none.
- Rulings: none (docs/reviews/rulings/ precedent consulted; nothing applicable).
- Unverified: stories 5-7 were assumed landed and were not inspected; the pre-check at build time confirms MeetingFinder.samePlace and the MemoryFilter helper. No builds, tests or devices were run.
