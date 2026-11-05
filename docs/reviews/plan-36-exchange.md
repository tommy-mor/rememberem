# Plan 36 (Ledger polish): crew exchange

**Commit:** 24e2922, Flutter 3.47.9.

**Who took part:** each agent ran as its own subagent, on sonnet.
- Plan check: archie, marlin and gill.
- Baseline: tess, hal and rex.
- Witness: ada.
- Facts: vera.

**Result:** the amendments are folded into
`docs/plans/36-ledger-polish-all-pages.md`. No stalemate went to the
TieBreaker. Three design calls went to Eric, who decided them.

## Plan check round 1, adopted

- **Behaviour changes.** "Visual only" was false. The plan now lists
  every behaviour change.
- **Theme before widgets.** No `LedgerAppBar`, `LedgerProgressBar`,
  `LedgerRow` or `GroupHeader`. One `SectionHeader` covers what those
  would have done.
- **Shared pieces.** Each is built by the first slice that needs it.
- **`DateGroups`.** It lives in the app, not in core. It takes a clock and
  is laid out as a flat `ListView.builder`.
- **Deletions.** A deletion checklist runs per slice.
- **Slices.** Six instead of eight. Capture is last, behind a device
  walk.
- **Gill's recall fixes:**
  - the countdown keeps the choices hidden;
  - the Details grid fits on screen;
  - names wrap;
  - wrong answers are never red;
  - Play again is dropped;
  - the results headers are kinder.

## Baseline objections and how each ended

| Id | Objection | Outcome |
| --- | --- | --- |
| H1 | Tap targets should be 48, not 44 | Accepted. 48 everywhere |
| H2/T7 | A global `InputDecorationTheme` silently restyles fields | The builders split. The guardians and marlin preferred the `ledgerDecoration` helper with a call-site table, and it was adopted. Archie preferred the theme plus deleting the explicit outlines; that position is recorded here |
| H3 | Theme `toolbarHeight`, the suffix colour, global `linearMinHeight` | vera sided with hal: the theme height *does* size the Scaffold's bar, so 52 dp stays. Suffix at 75 %, tested at 4.5:1. `minHeight` set at each use |
| H4 | The wording rule contradicts the new strings | Accepted. Strings table added, "Turn N of M" kept |
| H5 | The body contradicts the amendments | Accepted. Plan rewritten |
| H6/T3 | The Places estimate reference, and a scroll test that passed vacuously | Accepted. `collapsedExtent` is measured; a `getRect` test runs at 1.0 and 2.0 |
| H7 | No "balance" wrap in Flutter | Withdrawn after the fix |
| H8 | Wrong file and line references | Withdrawn after the fix |
| T1/R1 | Empty trash is an unsafe bulk purge | Resolved by dropping it (out of scope) |
| T2 | The list of tests to update was incomplete | Accepted. Named in the plan, with a grep checklist per slice |
| T4/R2 | Merge's two-step flow needs tests and rules | Accepted |
| T5/R5 | `DateGroups` edge cases, and stale groups after midnight | Accepted. Resume refresh in `MemoryListScreen` is new work (vera) |
| T6 | The accessibility table could pass vacuously | Accepted. Markers, waivers the test reads, checks at 2.0 |
| T8 | Pulse, toggle and snack bar tests | Accepted. Fixed vs floating snack bar left to Eric |
| R3/R4/W6 | Quiz photos at 2.0 scale and in landscape | Accepted. `LayoutBuilder`, minimum photo sizes, scrolling |
| R6 | Capture chrome and cold start | vera found that capture is **not** locked to portrait, and that the shortcut builds Home first. No overflow at 568×320. Cold start is timed with a large library |
| R7 | The pulse restarts in `didChangeDependencies` | Accepted |
| R8 | Card header with the keyboard up | Accepted. A keyboard-up entry in the accessibility table |
| W1–W8 | Ada's points | Accepted or mitigated: 12/13 sp minimums, check plus semantics for selection, a 48×6 outlined progress bar, 60 % underline, Timeline names, dark snack bar outline, consent page in the table |

## Facts vera settled

| Claim | Verdict |
| --- | --- |
| A theme `toolbarHeight` is ignored by the Scaffold | **False.** The Scaffold uses `AppBar.preferredHeightFor` (`app_bar.dart:238-243`, `scaffold.dart:3051`) |
| `androidTapTargetGuideline` is 48×48 | True (`accessibility.dart:785-786`) |
| The suffix icon is at least 48×48 whatever `isDense` is | True. With the default suffix this also makes a dense field at least 48 dp tall, unless a compact `VisualDensity` is inherited |
| Capture is locked to portrait | **False.** The manifest has no `screenOrientation`, and `Info.plist` allows landscape |
| The shortcut avoids Home | **False.** `MemoryListScreen` builds and reloads first |
| `MemoryListScreen` refreshes on resume | **False.** Only `RememberemApp` handles resume |
| The merge picker excludes the source person and pops; `_merge` merges | True |
| The card header is a top-aligned `Row` | True |
| The pulse restarts from `didChangeDependencies` | True |
| The three Undo snack bars last 6 s | True |

## Eric's decisions (2026-11-04)

1. The person card photo is 136 × 170, with a tap to see it full size.
2. Timeline thumbnails are 44 × 55, with the person's first name.
3. Snack bars are fixed, not floating.

**Not verified:** none of this has been seen on a device. Nobody checked
Roboto's tabular figures, nor the other snack bars' durations at
`memory_edit_screen.dart:597` and `:745`.
