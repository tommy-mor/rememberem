# Story 32: detail cards, grouped by type

## What Eric asked

1. Expanding a detail:
   - stops showing the collapsed summary;
   - puts a collapse toggle in the top-right corner, so he doesn't press a
     record button by accident;
   - shows all the input parts, with the description last;
   - keeps the ? and trash at the bottom.
2. Detail cards don't wrap their text. Their background is slightly darker
   on a light page, or slightly lighter on a dark page.
3. On the person card:
   - the "Details" label goes;
   - details are grouped by type under a bold label;
   - the add buttons go, and a small "+" sits beside each type label.
4. Subtypes: the custom-type field is hidden behind a "+" button, which
   opens a dialog asking for the new type's name.
5. A new detail shows expanded, and nothing takes focus (the keyboard is
   distracting at that moment).
6. Any empty text field with placeholder text shows it in italic and
   semi-transparent.
7. Red error text:
   - a collapsed tag with no subtype;
   - a collapsed anniversary with no date.
8. Anniversary with no date: a highlighted "+ date" button with a pulsing
   background.
9. Happening:
   - a "+ place" button with the normal look, when there is no place;
   - "+ home" was a typo for "+ place" (Eric confirmed).

   Happenings keep being stamped with the moment they are added (Eric's
   call), so a happening always has a date. Its "+ date" and red "no date"
   never arise, and none are built.

## Design

All in `app/lib/src/memories/`. No data change.

### Grouped sections

- `DetailListEditor.build` shows one section per `DetailKind`, in enum
  order, even when it is empty. Each section has:
  - a header row: the plural label in bold (`titleSmall`, w700):
    "Facts", "Happenings", "Relationships", "Anniversaries", "Tags";
  - a compact "+" `IconButton` right after the label, with the tooltip
    "Add a fact" and so on;
  - the section's details below, in their saved order.

  `DetailKind.plural` is added in core.
- The "Details" title and the row of add buttons go. The ? (kind help)
  stays in each open card.
- The saved order of `details` is unchanged; grouping is display only.

### Collapsed card

- A `Material` card (radius 8) whose colour is the page background shifted
  6 % toward black on a light page or toward white on a dark page
  (`DetailCardTint.of(context)`, by `Theme.brightness`). It holds one line
  (`maxLines: 1`, ellipsis):
  - the summary is `fieldPrefix` + text (as now, with the kind dropped,
    since the section header names it). A happening shows its date and
    place first: "3 Mar 2026 · Park - text".
  - an empty description shows its placeholder: the kind's
    `DetailPrompt` style hint, italic.
  - an error, when there is one, is a second line in `colorScheme.error`:
    "No tag chosen" for a tag with no label, "No date" for an
    anniversary without an `eventDate`.
  - the trailing icon is `expand_more`.
- Tapping anywhere on the card opens it. The collapsed card is not a text
  field, so there is no mic and no typing while collapsed.

### Open card

- The same tinted card, outlined in `primary` (1.5 px), holding:
  - a top row: the kind label (bold) and, top right, an `expand_less`
    toggle ("Close <name>");
  - the kind's extras (`DetailExtrasEditor`), as now, except where amended
    below;
  - the description, last: a `DictatedTextField`, label "Description", no
    prefix, multiline, with the mic;
  - the bottom row: ? on the left, trash on the right, as now.
- It closes by the toggle, or by a tap outside, as now. It stays open
  while listening, and while a picker is over the page.
- **New details** open with nothing focused: `autofocus` goes, along with
  `_added`.

### Extras amendments

- **Types:**
  - the custom `TextField` goes. After the chips sits an "+" `ActionChip`
    (tooltip "New <kind> type").
  - it opens `NewTypeDialog`, an `AlertDialog` with one autofocused
    `TextField`, "Name" (lower-case kept as typed), and Cancel and Add.
  - Add, with a non-blank name, sets `label`. The name joins the local
    chip list, selected; a name matching an existing chip by
    `normalizeKey` selects that chip.
  - the tag help text ("Tags group people…") shows only while no tag type
    exists at all, as now.
- **Anniversary date:** with no `eventDate`, a `PulsingButton` labelled
  "+ date" stands where the date tile would be:
  - a `FilledButton.tonal` whose background pulses between
    `secondaryContainer` and `primaryContainer`, every 900 ms, repeating;
  - static when `disableAnimations` is set.

  With a date, the tile shows as now, still tappable to change it.
- **Happening place:** with no place, the "Where it happened" tile is
  replaced by an `OutlinedButton` "+ place". With a place, the tile shows,
  with a clear button.
- The tag "+ place"/"+ date" buttons stay as they are.

### Placeholders

- `RememberemTheme` `inputDecorationTheme.hintStyle`: `fontStyle: italic`,
  with the `onSurface` colour at 50 % alpha. Every field with a hint
  follows it.

## Tests

- **Sections:**
  - five headers, in order;
  - "+" on a header adds that kind, which opens expanded with no focus
    (`FocusManager.primaryFocus` holds no EditableText);
  - no "Details" title and no "+ fact" button.
- **Collapsed:**
  - one line;
  - the summary text with prefix;
  - the error lines for a typeless tag and a dateless anniversary.
- **Open:**
  - the toggle closes it;
  - the description is last, and ? and trash are below it;
  - the mic shows only when open.
- **Types:** "+" opens the dialog; Add sets the label and selects the
  chip; Cancel changes nothing; a blank name is refused.
- **Pulsing "+ date"** on a dateless anniversary, which opens the date
  picker; a happening with no place shows "+ place".
- **Tint:** darker than the page on light and lighter on dark (a pure
  function test).
- **The hint style** is italic.
- Existing detail tests are updated for the new layout.

## Amendments after Plan check (archie, marlin, gill)

- **`DetailSummary`** (core, `detail_summary.dart`) takes over
  `prefixParts`, `fieldPrefix` and `spokenName` from `DetailListEditor`.
  `lineFor(detail, nameOf, {withKind})`:
  - **Collapsed card** (`withKind: false`): "Brother: Ann - text",
    "Wedding: 3 Jun 2010 - text", "3 Mar 2026 · Park - text",
    "Relatives · Park - text", "text".
  - **Match lines** (story 33, `withKind: true`) put "Fact · ",
    "Happening · " or "Tag · " before fact, happening and tag lines. A
    relationship or anniversary needs no kind.
- **Tint** is inline: `Color.alphaBlend` of black or white at 6 % over the
  scaffold background, in one small static helper.
- **Collapsed rows are no longer text fields.** This is a rewrite of the
  row build, sized M.
- **Kept as Eric asked** (gill objected): all five headers with "+", and
  the pulsing "+ date" while an anniversary has no date.

## As built (after Baseline; supersedes the above)

- `DetailSummary` (core) has `prefixParts`, `prefix`, `lineFor`,
  `kindHead` and `spokenName`. `DetailKind.plural` is added.
- **Closed cards** are no longer text fields, so story 19's "the field is
  never remounted" no longer holds. It is not needed: a card cannot close
  while listening, and nothing dictates into a closed card.
  - The closed summary uses `nothingYet` (italic hint style) when empty,
    and `problemOf` in red.
  - The tint is `alphaBlend` of black or white at alpha 16 over the
    scaffold background.
- **Open cards:** the kind and a close toggle at the top, the extras, the
  "Description" field (hint "What to remember") last, then ? and delete.
- **Types:** a "New" `ActionChip` opens `NewTypeDialog`. A type made here
  joins the chips, and a type already in use is listed even if no one
  else has it.
- **`PulsingButton`** "+ date" on a dateless anniversary (still when
  animations are off). A happening without a place shows "+ place"; with
  one, a clearable tile.
- **Hint style:** italic, `onSurface` at 50 % (theme-wide).
- `DetailListEditor` takes `generation` (Undo, story 34) and
  `onListeningChanged`.
