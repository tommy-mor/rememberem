# Story 28: settings boxes, backgrounds, photo check, timeline details

## What Eric asked

1. Settings sections: make the section name's font 30% larger. Draw a box
   round each section with its name on the border, like details have. Make
   the section's background slightly darker on light backgrounds and
   slightly lighter on dark ones.
2. Make the background choices more saturated, and add a few dark
   background options.
3. When taking a photo, ask whether it is OK before using it, with an
   option to retake it.
4. A "Show details" checkbox on the timeline page. It adds happenings,
   tags and the most recent anniversaries to the timeline.

## Design

### Settings sections

- `SettingsSection(title, children)` replaces `SettingsHeading`. It is an
  `InputDecorator` with:
  - an `OutlineInputBorder`;
  - the title as an always-floating label, in titleMedium × 1.3 and the
    primary colour;
  - `filled` with `onSurface` at 4% alpha blended over the surface, which
    is darker on light pages and lighter on dark ones.

  Children sit in a Column with 8 dp margins between sections.
- Reminders, Display, Matching, Practice and Maps each become a section.

### Backgrounds

- **Light choices, more saturated.** The same names, deeper tints, with
  white kept:

  | Name | Old | New |
  |---|---|---|
  | light blue | E9EEFC | D3DEFA |
  | cream | FFF8E7 | FCEFC7 |
  | mint | E8F5EE | CDEEDB |
  | lavender | F1EAFB | E2D3F7 |
  | blush | FCEDEE | F8D5D9 |
  | pearl | F1F3F5 | E1E5EA |

- **New dark choices:** Midnight 0F1B33, Charcoal 1E2023, Pine 10291F and
  Aubergine 261631.
- **Theme.** A dark background gives dark pages: a dark scheme from the
  theme colour, with `surface` set to that background. Dark mode's own
  switch stays. With dark mode on and a light background chosen, pages use
  the standard dark surface, as now. With a dark background chosen, it is
  used whatever the switch says.
- **Migration.** `AppSettings.fromJson` maps the six old light values to
  their new ones, so a saved choice keeps its name. Unknown values fall
  back to the first, as now.
- Contrast: body text on each background passes 4.5:1. A test checks it.

### Photo check

- After the shutter, the camera screen shows the still photo full screen
  with "Retake" and "Use photo". The photo is not processed until "Use
  photo". Retake drops it (bytes in memory only; the temp file is already
  deleted) and returns to the live camera.
- Photos picked from the phone skip the check, since the gallery was the
  choice. The camera stays open underneath, so Retake is instant.

### Timeline "Show details"

- A `CheckboxListTile` "Show details" at the top of the timeline (not on
  a single day's page; that page follows the main timeline's choice). The
  value is held for the session in AppServices, alongside the list
  filters, and is not saved.
- **Off:** people sit on the days they were met (each encounter's day),
  grouped by place and meeting. This replaces today's use of happening
  days.
- **On:** the timeline also adds:
  - each happening, on its day, at its place;
  - each tag with a date, on that date, at the tag's place;
  - each anniversary on its most recent occurrence, on or before today.

  A person appears in the group, and under their photo a small line names
  the detail ("Wedding anniversary", "Book club", "Happening: picnic").
- **Core:** `TimelineBuilder.build(active, {only, details, today})`.
  - `TimelineGroup` gains `details: Map<String, List<Detail>>`, keyed by
    person id.
  - The "recorded" notion goes. Every person now has at least one met
    day, so no stand-in is needed.

## Tests

- Core:
  - the timeline off by met days;
  - on, it adds happenings, tag dates and the latest anniversary
    occurrence (with a year rollover and a future date this year going to
    last year);
  - legacy background migration;
  - dark backgrounds are known.
- App:
  - Settings has a box per section with the larger title;
  - a dark background gives a dark theme;
  - the camera's check (Retake returns to the camera; Use photo saves);
  - the timeline checkbox shows detail lines.
