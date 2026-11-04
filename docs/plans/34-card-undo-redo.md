# Story 34: undo and redo on the person card

## What Eric asked

"Add little undo/redo buttons at the bottom of the person edit page. The
undo context should disappear when the user goes to another page."

## Design

### Scope

- The card's name, place and meeting fields, and its details: text, add,
  delete, and type, date, place or person changes.
- Not covered (each already has its own Undo snackbar, or is not an edit
  of this card's fields):
  - pictures (an encounter's removal and restore);
  - crop;
  - contact link;
  - merge;
  - trash.

### `EditHistory` (core, pure Dart)

- Holds "states": a `CardState(fields, details)`, which is
  `Memory.fields` and `Memory.details`.
- `record(before, {String? coalesceKey})` pushes `before` on the undo
  stack and clears redo. Consecutive records with the same non-null
  `coalesceKey` (typing in one field or one detail's description) make one
  step. Any other record, or any undo or redo, ends the run.
- `undo(current)` returns the state to restore and pushes `current` on
  redo. `redo(current)` mirrors it. There are `canUndo` and `canRedo`.
- At most 100 steps; the oldest drops.

### `MemoryEditor`

- Each mutating method (`update`, `addDetail`, `replaceDetail`,
  `updateDetail`, `deleteDetail`, `restoreDetail`) records the state
  before it through the history. Typing uses coalesce keys
  `field:<key>` / `detail:<id>`.
- `undo()` / `redo()` set `_memory` to the restored fields and details
  (encounters, contact and score untouched), update `_deleted` (ids no
  longer present are deleted; ids present again are not), and save at
  once (`_flushNow`). A `ChangeNotifier`-style `historyChanged` callback
  lets the card rebuild the buttons.
- `save()` already keeps stored points, so undo never undoes a game
  result.

### The card (`memory_edit_screen.dart`)

- At the bottom, beside "Saved automatically.", there are two small
  `IconButton`s, `undo` and `redo` ("Undo", "Redo"), disabled when there
  is nothing to undo or redo.
- After an undo or redo, the text fields and detail rows are rebuilt from
  the restored values: `_fieldsGen++`, and the detail rows' text fields are
  keyed with a generation too. Open rows stay open if their detail still
  exists.
- Undo is refused while a dictation is live (the button is disabled), so a
  late result can't land on a restored field.
- **"Disappears when the user goes to another page."** The history lives
  with the card's editor, so closing the card ends it. It is also cleared
  when another person's card or a picture page is pushed over this one
  (`RouteAware.didPushNext` through the app's route observer, which is
  already passed to the list). Pickers are exempt: they are dialogs, and
  the map location picker is opened by the card for a field. It is
  cleared there only if the pushed route is not one the card opened for an
  edit (`_pickingPlace`).
- The detail delete snackbar's Undo stays. It goes through
  `restoreDetail`, which records history like any edit.

## Tests

- **Core `EditHistory`:**
  - record, undo, redo;
  - redo cleared by a new record;
  - coalescing;
  - the 100-step cap.
- **`MemoryEditor`:**
  - undoing typed text, an added detail, a delete, a type change;
  - redo;
  - undo saves;
  - undo after a game result keeps the points (repository-level);
  - a late dictation into a detail removed by undo is ignored.
- **Card widget:**
  - the buttons are disabled at first;
  - typing a name then Undo restores the field text;
  - Redo re-applies it;
  - opening a related person clears the history.

## Amendments after Plan check (archie, marlin)

- **No `RouteAware`** (archie: the card has no route observer). The card
  calls `_editor.clearHistory()` at its own pushes:
  - opening a related person (`_openRelated`);
  - a picture's page (`_openPicture`);
  - merge.

  Crop and the location picker keep the history. A notification tap over
  the card is an accepted gap. The history goes when the card closes.
- **`EditHistory`** lives in `app/lib/src/memories/edit_history.dart`
  (one consumer). It is pure Dart and unbounded while the card is open, so
  there is no cap and no cap test.
- Coalescing by key stays (marlin preferred debounce snapshots). Keys make
  "undo" undo one field's typing, which is predictable. The cost is one
  `_history.record` line in each mutator.

## As built (after Baseline; supersedes the above)

- **`EditHistory`** (app) is unbounded and coalesces by key. `CardState`
  holds the three card fields by key (place and meeting through the
  newest encounter) and the details.
- **`MemoryEditor`** is now a `ChangeNotifier`:
  - `undo`, `redo` and `clearHistory`;
  - every field or detail mutator records first;
  - `_restore` saves at once and un-deletes the ids present again.
- **The card:**
  - Undo and Redo sit either side of "Saved automatically.";
  - they are disabled while any field or detail is dictating (`_dictating`,
    fed by `onListeningChanged`);
  - after a step, `_fieldsGen` and `_detailsGen` bump, so the fields reread
    their text;
  - the history is cleared on opening a related person, a picture page, or
    merge.
- **The rex race** (a late word after Undo): fixed at the source.
  `DictatedTextField` drops words once it stops listening, and
  `DeviceDictation` delivers the final words before "done".
