# Story 25: filters on the main list, sorting, match lines, Home

## What Eric asked

- Remove the Filter List page and put its filters on the main list.
- Add a sort-by choice: first name, last name, date. Choosing the same sort
  again reverses the order.
- A date range applies to picture dates, and to people with details whose
  dates fall in it. Anniversaries match on month and day, not year. With a
  date range on, each card also shows its picture dates in range and a list
  of the matching details (type, subtype and date). Cards may be taller and
  vary in height.
- With a "Details contain" filter, each card shows a small list of the
  details that match, with the matching text highlighted. The match looks
  at the subtype (label) as well as the description.
- Add a Home button to the title bar of every page but the list.

## Core (pure Dart)

- `DateRangeFilter` also matches details:
  - a happening on its date (`at`);
  - a tag on its `eventDate`;
  - an anniversary yearly on its month and day, the `AnniversaryFilter`
    rule, which moves to a shared `AnniversaryFilter.fallsIn(start, first,
    last)`.

  New methods:
  - `encountersIn(memory)` gives the encounters in range;
  - `detailsIn(memory)` gives the matching details.

  Facts and relationships have no date of their own, so they never match.
- `DetailsFilter` matches the description or the label. `detailsIn(memory)`
  gives the matching details. `spans(text)` gives where the needle sits in
  a string, for highlighting.
- `PersonSort` is an enum: `firstName`, `lastName`, `date`.
  - `PeopleOrder(sort, reversed)` has `apply(list)`.
  - First name is the first word of the shown name and last name is the
    last word. Ties fall back to the full name.
  - Unnamed people sort last whichever way the list runs.
  - Date means the newest encounter, newest first (today's order).
    Reversed means oldest first.

## App

- `ListFilters` is a `ChangeNotifier` owned by `RememberemApp`. It holds:
  - the filter conditions, each keyed by id as on today's Filter List;
  - an optional note ("Add their names while you remember.");
  - the `PeopleOrder`.

  `show(filters, note:)` replaces them. That is how the anniversary notice
  and the group-photo flow set the list: pop to the list, then show. Not
  saved; a restart clears it.
- `MemoryListScreen` replaces its list with a `CustomScrollView`:
  - the filter rows;
  - a row with "Add filter" (a popup of the kinds), a "Sort" popup (with a
    check on the current sort and an arrow for its direction) and the count;
  - the people.

  "Practice" stays at the bottom and still uses everyone; story 26 changes
  that. The empty-list text shows only when there is no one at all; with
  filters and no matches it says "No one matches."
- `MemoryTile` gains an optional `below` widget. `FilterMatchLines` builds
  it from the active date range and details filters:
  - "Photo · 3 Mar 2026" for each encounter in range;
  - "Anniversary · Wedding · 3 Jun 2010" for each detail in range;
  - for a details filter, "Fact: She **sings** bass" in small text, with
    the matched part bold and in the primary colour.
- `FilterListScreen` is deleted. `AppRoutes.anniversaries` goes too, since
  a notice now lands on the list itself. The anniversary notice still skips
  a week with no matches and never opens over the camera or a game.
- `HomeButton` is an icon button (a house, tooltip "Home") that pops to the
  first route. It sits in the actions of every AppBar except the list's.
  It takes an optional `Future<bool> Function()` to run first:
  - the person card flushes;
  - the face picker asks to discard, as its Back does;
  - group details is disabled while saving.

## Tests

- Core: a date range matches a happening, a tag date and an anniversary's
  month and day across a year end, and never a fact. `detailsIn` and
  `encountersIn` work. Details contain matches a label. Every `PersonSort`
  works, with unnamed people last and reverse order.
- App:
  - filters on the list narrow it, and "No one matches." shows;
  - choosing a sort twice reverses it;
  - match lines appear with a date range and highlighted text with details
    contain;
  - an anniversary notice and group details land on the filtered list;
  - Home from a card saves and returns to the list.
  - Existing Filter List tests move to the list.
