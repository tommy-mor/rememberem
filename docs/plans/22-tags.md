# Story 22: tags

Eric: "A tag is another type of detail. Tags have a subtype that works the
same as anniversary and relationship subtypes. If there are no tags defined,
explain to the user that tags are a way to group people arbitrarily, e.g.:
relatives, celebrities, memberships, etc. Then invite them to create their
own tags. Tags can have an optional place and time. When showing a tag in a
list, put the detail type in the border and this in the main area: [tag
type] [place if there is one] [Date if there is one] - [Description]."

## Behaviour

- **A new kind.** `DetailKind.tag` ("Tag") is added after anniversary, and
  the person card gets a **+ tag** button.
- **The tag type.** It is the detail's `label`, chosen from chips or typed as
  a custom type, as relationships and anniversaries are. There are no
  built-in tag types. The chips are the tag types already in use (active and
  trashed people, as `DetailTypeCatalog` does today).
- **No tags yet.** While no tag type exists, the type area says: "Tags are
  a way to group people any way you like: relatives, celebrities,
  memberships and so on. Make your own below." The custom box is labelled
  "Create a tag".
- **Optional place and date.** The place is picked on the map, as a
  happening's place is. The date is a calendar day (`eventDate`), picked
  with a date picker and clearable. "Time" is taken to mean the day; there is
  no clock time.
- **In the details list:**
  - The border label is just "Tag".
  - The field begins with a fixed prefix, then the editable description:
    `Relatives · Park · 3 Mar 2026 - ` (only the parts that exist; with no
    parts, no prefix).
- **Elsewhere.** `DetailPrompt.prefix` for a tag is "Relatives, Park, 3 Mar
  2026", so `full` reads "Relatives, Park, 3 Mar 2026: description" wherever
  details are listed as text.
- **Not in Practice details.** Many people share a tag, so "who is in the
  book club?" has several right answers.
- **Filter List.** A new **Tag** filter kind is a dropdown of the tag types
  in use. It matches people with that tag (ignoring case and spacing).
  Without it, tags would group no one. Eric did not ask for it in so many
  words; it is the smallest thing that makes "group people" true.

## Data

`type: "tag"`, plus the existing optional `label`, `place` and `eventDate`.
These are new values of existing keys, so no migration is needed. Older app
versions read an unknown `type` as null, so a tag shows as a fact there; it
is not lost.

`Detail.copyWith` cannot clear `eventDate` today. To make the date
clearable, `eventDate` becomes a function argument, as `targetId` is.

## Tests

- **Core:**
  - `DetailKind.tag` round-trips;
  - `DetailTypeCatalog.labels(tag)` returns only types in use;
  - `DetailPrompt` prefix and full;
  - the quiz planner skips tags;
  - `TagFilter` matching;
  - an old-app read leaves a tag as a fact.
- **App:**
  - **+ tag** adds a tag row;
  - the explanation appears when no tag exists, and is gone once one does;
  - choosing a type, a place and a date shows the prefix in the field and
    "Tag" on the border;
  - clearing the date;
  - the Tag filter on the Filter List.

## Plan check amendments (`archie`, `grace`)

- **Prefix:** `DictatedTextField` gains an optional `prefix`, shown as
  `InputDecoration.prefixText`. It is not part of the text, so dictation and
  autosave never see it. A long prefix wraps on the multiline field; this is
  accepted.
- **Explanation:** it shows only while no tag type exists and this tag's
  type is still blank, so it never goes stale after Fred types a first type.
- **Tag filter:** wired through `FilterKind` (`blank` and `of`), the
  `FilterRow` input and `FilterListScreen`, which passes the tag types, with
  a widget test.
- **Date:** the date row has a Clear button once a date is set.
- **No keyboard:** a new tag row doesn't take the keyboard, as a
  relationship doesn't. The type comes first.
- **Older builds:** the wording is corrected. An older build that saves the
  record turns its tags into facts for good, though the text, type and date
  stay in the file. This only matters with mixed versions.
- **Kindness:** under "Create a tag": "Keep tags kind: words the person would
  be happy to read." (`grace`). Eric's examples, celebrities included, are
  kept.
