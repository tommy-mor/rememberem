# Story 33: filters start ready to fill in; clearer match lines

## What Eric asked

1. "When adding a filter, immediately put the user in the input mode for
   that filter."
2. On the person list:
   - anniversaries drop the words "Anniversary" and "every";
   - relationships drop "Relationship", and show the other person's name
     after the subtype and before the description;
   - happenings show their date before the description;
   - the detail list doesn't collapse until there are at least 5 matching
     details.

## Design

### Input mode on add (`filter_bar.dart`, `filter_row.dart`)

When a filter is added, what happens depends on its kind:

- **Name contains / Details contain:** the field is focused, as now
  (`autofocus` on `filters.added`).
- **Place, Meeting and Tag:** the choice opens at once.
  - `FilterRow`'s dropdown becomes a tappable field (`InputDecorator` with
    "Choose", like the date fields). It opens `ChoiceSheet`, a modal bottom
    sheet listing the names, the current one ticked.
  - when the row is added, `FilterBar` opens the sheet after the frame.
- **Date range and Anniversary:** the date range picker opens at once,
  after the frame.
- **Cancelling** that first sheet or picker removes the just-added filter,
  which is still blank, so a filter is never left half made. Cancelling
  later, on an existing filter, keeps it.
- `ListFilters.added` is cleared once used (`ListFilters.consumeAdded()`),
  so a rebuild never reopens it.

### Match lines (`filter_match_lines.dart`)

Each line uses the person card's own summary words.
`DetailSummary.lineFor(detail, nameOf)` is shared with story 32's
collapsed card:

| Kind | Line |
|---|---|
| Relationship | "Brother: Ann Lee - helps at the cafe" |
| Anniversary | "Wedding: 3 Jun 2010 - at the lake" |
| Happening | "Happening · 3 Mar 2026 - ran the marathon" |
| Fact | "Fact · loves jazz" |
| Tag | "Tag · Relatives · Park · 3 Mar 2026 - text" |

- The kind is kept only where the line would otherwise be ambiguous (fact,
  happening, tag). It is never searched or highlighted.
- A "Details contain" match bolds the found words anywhere in the subtype,
  name and description part. Spans are computed on the line itself
  (`DetailsFilter.spans(line)`), offset past any head.
- A date-range match on a detail uses the same line (without the
  description when there is none).
- `FilterMatchLines` needs `nameOf`: the list passes active names, as
  `memory_list_screen` already builds for the tiles.
- **Collapse:** up to 4 lines show in full. With 5 or more, the first 3
  show, then "+N more" (`most` becomes 4, and `shownWhenCollapsed` 3).

## Tests

- Adding Place opens the sheet; picking sets it; cancelling removes the
  filter.
- Adding Date range opens the picker; cancel removes it.
- Adding Name focuses the field; a later rebuild does not reopen anything.
- The line texts for each kind; highlighted spans in a relationship's name
  and description.
- 4 matches show 4 lines; 5 show 3 lines and "+2 more".

## Amendments after Plan check (archie, marlin)

- **Lines** use `DetailSummary.lineFor(withKind: true)` (story 32). The
  filter's own `_dated` goes.
- **Choosing at once:**
  - for Place, Meeting and Tag, the dropdown stays. `FilterRow` takes an
    `openNow` flag. When it is set, the row opens its own chooser after the
    first frame.
  - Flutter's `DropdownButton` has no public open, so the row is a
    tappable `InputDecorator` that calls `showModalBottomSheet` with the
    names, the same pattern as `contact_link_button.dart`. Its "Choose"
    look is the same.
  - for the date kinds, `showDateRangePicker` opens.
- **`consumeAdded()`** is called by `FilterBar` in a post-frame callback,
  never during build. Cancelling the first open removes the filter through
  `ListFilters.remove(id)`, guarded by `mounted`.

## As built (after Baseline; supersedes the above)

- **`FilterRow`** is stateful.
  - With `openNow`, it opens its own chooser once, after its first frame:
    - a bottom sheet for place, meeting and tag (the dropdown is
      replaced by a tappable field that opens the same sheet);
    - the date range picker for the date kinds;
    - text kinds autofocus.
  - Cancelling that first choice calls `onRemove` (no `mounted` guard;
    rex), and dismissing the sheet counts as cancelling.
  - `ListFilters.consumeAdded(id)` runs in the post-frame callback,
    without notifying. Each row keeps its own `openNow` from its own state,
    so a quick second add cannot steal the first's open.
- **Match lines** are `kindHead + DetailSummary.lineFor`. Up to 4 show;
  5 or more show 3 and "+N more". The list passes active names for
  relationships.
