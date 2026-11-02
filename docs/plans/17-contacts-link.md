# Story 17: Connect a person to a phone contact

## Goal
From a person's card, Fred links the person to one entry in his phone contacts. The first tap opens a dialog scrolled to the most likely name match (Eric's decision, fixed). Once linked, a tap opens that contact in the phone's contacts app. A long press offers Re-assign or Remove link. The record keeps one opaque key and never a copy of contact data.

## Acceptance criteria
1. The card app bar, which today has only a title, gains an `actions` entry with a contact icon (outlined when unlinked, filled when linked), shown only when `services.contacts` is non-null. Capture, "Meet someone" and autosave never touch contacts.
2. First tap, unlinked: the app explains in one line and asks for contacts permission. If granted, a dialog lists contacts A to Z, scrolled so the best match to the person's name is at the top and highlighted. Fred can type to filter.
3. Choosing a contact links it and closes the dialog. The record gains no contact name, number, email or photo.
4. Tap, linked: the phone's contact detail opens. When Fred returns, the card is unchanged and no note is lost.
5. Long press, linked: a sheet offers Re-assign (opens the dialog) and Remove link. Remove clears only this record and never writes to the phone. Long press, unlinked: same as a tap.
6. If permission is not granted (denied or permanently denied, treated the same), the system contact picker opens instead (no pre-scroll). If there is no contacts app, a plain message appears. The icon is never dead, there is no prompt loop, and nothing crashes. Overlapping calls are safe: a second tap or long press while a call is in flight is ignored, a result that arrives after the card was popped is dropped (no exception, no write), and a cancelled or lost picker result leaves the record unchanged.
7. If the linked contact no longer exists, a tap shows a "Contact not found" snackbar saying a long press can re-assign or remove the link (no separate sheet). The link is never removed automatically. Without READ_CONTACTS a stale key cannot be detected, so the Contacts app shows its own not-found.
8. The link survives autosave, score updates, trash and restore. Merge: the survivor keeps its own link, else adopts the discarded person's. Purge removes it with the record.
9. Records written before this story load unchanged and are not rewritten on open.
10. On iOS `services.contacts` is null and no icon is built (unverified, see Risks).

## Design
**Data.** `Memory.contactKey` (String?, top-level, not in `fields`, so no screen iterates it). It holds the Android `LOOKUP_KEY`, which survives sync re-keying, unlike the numeric id. `toJson` writes `contactKey` only when non-null. `fromJson` accepts only a non-blank String, so anything else loads as no link and loses no other field. Add the member to the constructor, `withTrashedAt`, `withScore`, `merged` (`contactKey ?? other.contactKey`), `_copy`, and a new `withContactKey(String?)` (four hand-written constructors, so a unit test checks every `with*` keeps the key) in `packages/rememberem_core/lib/src/memory.dart`. Old records have no key and need no migration. An older build drops the key on its next save (rollback note).

**Repository.** Add `setContactKey(String id, String? key)` to `MemoryRepository` and `JsonFileMemoryRepository`. It runs on the `_serial` chain, refuses purged ids, and works on trashed ones. `save()` keeps the stored `contactKey` by chaining `.withContactKey(onDisk.contactKey)` beside the existing `withTrashedAt/withScore/withDetailScores` calls, so a stale editor copy cannot undo it. Update `app/test/fakes/fake_memory_repository.dart`.

**Contacts service** (app, one class per file, under `app/lib/src/contacts/`):
- `contacts_service.dart`: interface with `Future<bool> ensureAccess()` (true only if READ_CONTACTS is held after asking), `Future<List<ContactEntry>> list()`, `Future<String?> pickWithSystemPicker()`, `Future<ContactOpenResult> open(String key)` (opened, notFound, noApp). There is no blocked or denied state: any non-granted result takes the picker fallback.
- `contact_entry.dart`: `{key, displayName}`. Nothing else is read.
- `contact_matcher.dart` (pure Dart, kept in the app beside its only user and tested in `app/test`, not core): `bestIndex(entries, name)` scores exact, then equal token sets (so "Lee, Ann" matches "Ann Lee"), then prefix, then shared tokens, with case and accents folded. It returns -1 for a blank name or no match, and the list then starts at the top.
- `android_contacts_service.dart`: a MethodChannel `rememberem/contacts` backed by `ContactsChannel.kt`, registered in `MainActivity`. It uses `READ_CONTACTS` and reads only LOOKUP_KEY and DISPLAY_NAME_PRIMARY. Permission is requested with `requestPermissions` from `MainActivity`, whose `onRequestPermissionsResult` completes the pending result (distinct request codes from the picker's `onActivityResult`); no permission_handler dependency. `open` works without READ_CONTACTS: when held, it first checks `Contacts.lookupContact(resolver, lookupUri)` (null means notFound); when not held, it skips the check. Either way it fires ACTION_VIEW on `ContactsContract.Contacts.CONTENT_LOOKUP_URI/<key>` and maps `ActivityNotFoundException` to noApp. It never uses `resolveActivity`, which Android 11 package visibility can make return null. The system picker is ACTION_PICK on `Contacts.CONTENT_URI`, needs no permission, and returns the lookup key. A Kotlin channel is chosen over `flutter_contacts` because that plugin brings write access, photos and phones, and the channel follows the story 15 pattern. Add `READ_CONTACTS` to the manifest, plus keep rules if the release walk needs them.
- **Overlap and lifecycle guards.** `ContactsChannel.kt` keeps one pending result per operation (permission, picker) and answers a second call while one is pending with error `busy`, never overwriting the first (the `OriginalPhotoPicker.kt` pattern: `pending` field, guard, complete and clear). Dart maps `busy` to a quiet no-op. `ContactLinkButton` has a busy flag that ignores taps and long press while a call is in flight, and checks `mounted` after every await before using context or calling `setContactKey`; a link chosen after the card is gone is dropped. A lost picker or permission result (Activity recreated) leaves the record unchanged and is accepted as "tap again", not engineered around (YAGNI); the busy flag lives in the widget and resets when the card reopens.
- `contact_picker_dialog.dart`: a searchable list with a fixed `itemExtent`, scrolled to `bestIndex * itemExtent`. The list lives in State only. It is never logged, cached, or placed in an error message.
- `contact_link_button.dart`: the app-bar icon with tap, long press (Re-assign / Remove link sheet) and the not-found snackbar. Every call is wrapped in try/catch (including Error) and shows a generic message.
- `AppServices.contacts` is optional, so tests inject a fake. Following `main.dart:56`, it is `Platform.isAndroid ? AndroidContactsService() : null`.

**UI.** Add `actions: [ContactLinkButton]` to the existing `AppBar` in `memory_edit_screen.dart` (Merge is a body button, not an app-bar icon), with a tooltip and a 48 dp target. Remove link needs no confirmation: it is non-destructive and re-linkable.

## Tests
Core (`packages/rememberem_core/test/contact_key_test.dart`; matcher test lives in app):
- Round trip: save and load keep the key. A record without the key writes no `contactKey` and is not rewritten on open. A malformed value loads as no link with fields intact.
- Merge: an unlinked survivor adopts; a linked survivor keeps its own; merging the same pair twice changes nothing.
- `setContactKey` then `save()` of the pre-assign copy leaves the key unchanged. Trash and restore keep it. Purge removes it and touches no other record.
- `ContactMatcher` (in `app/test`): "Ann Lee" picks "Lee, Ann" and "Ann Lee" over "Annabel"; blank gives -1; accents fold.

App widget (`app/test/contact_link_test.dart`, with `FakeContactsService`):
- First tap with granted access shows the dialog with the best match visible and highlighted; selecting calls `setContactKey` once.
- Linked tap calls `open(key)` once. Long press shows Re-assign and Remove link; Remove writes nothing to the phone (the fake records no writes).
- `notFound`: a message appears, the key is unchanged and the notes are intact. `ensureAccess` false falls back to the system picker. `noApp` shows a message and nothing throws.
- With `services.contacts` null, no icon is built.
- Overlap: a fake whose `ensureAccess` completes after the screen is popped causes no exception and no `setContactKey` call. A double tap, and a tap during the long-press sheet, give a single dialog and a single `ensureAccess` call. A null picker result leaves the key unchanged.
- Core-model test: every `with*` and `merged` keeps `contactKey`.
- An autosave of the name after linking keeps the key (MemoryEditor with the fake repository).

Device (Galaxy S22, plus the emulator with seeded contacts): link, open, re-assign, remove, delete the contact then tap. Run once on a release APK. Restart the app and confirm the link survives.

## Risks and mitigations
- **Privacy.** READ_CONTACTS exposes people who never consented. Mitigate by reading id and name only, holding them for the dialog's life, never logging them, asking at first tap with a plain reason, and falling back to the permission-free picker. Play treats READ_CONTACTS as sensitive (declaration needed before a public release). Invariant 12 holds because the channel has no network code.
- **Wrong contact after a backup restore** onto another phone (open risk 6). The tap only opens the contact and the card shows no cached name, so Fred sees whose contact it is. Excluding the key from backup stays under risk 6.
- **Denied looks like not found.** Without READ_CONTACTS `open` skips the lookup check and delegates to the Contacts app, and a failed lookup never clears the link.
- Two people may link to one contact. This is allowed and not deduped.
- **iOS** cannot be built here. No icon is built and nothing is claimed verified. A later story would add CNContactPickerViewController and NSContactsUsageDescription.
- **Release shrinking:** a plain Kotlin channel probably needs no keep rules; the mandatory release APK walk confirms it.

## Out of scope
iOS support, creating or editing phone contacts (no WRITE_CONTACTS), showing the contact's name, number or photo on the card, auto-linking, bulk linking, and excluding the key from backup.

## Baseline record changes
Add a Story 17 entry covering: the `contactKey` top-level key (LOOKUP_KEY only, omitted when absent, kept by save, trash, restore and merge with survivor-wins-else-adopt, cleared by purge); the READ_CONTACTS permission and its picker fallback; no contact data stored; the rollback risk (older builds drop the key); iOS hidden and unverified. Update the Platform line to list READ_CONTACTS, note under invariant 12 that the channel has no network code, and add the wrong-contact-after-restore note to risk 6.

## Review record
- **Crews that ran:** Plan check (builders: Archie, Marlin), Baseline (guardians: Rex, Sally, among others), one round of rebuttals each way, then `vera` to settle facts. TieBreaker did not run: no stalemates.
- **Objection 1 (Rex):** no guard for overlapping contact calls, Activity recreation, or the card being popped during a permission, picker or list await; AC6 untested on these paths. Archie and Marlin accepted. Settled by `vera` as agreed (evidence: `OriginalPhotoPicker.kt` already has the `pending` guard pattern, which the new channel must copy). Applied: the "Overlap and lifecycle guards" Design item, the added sentence in AC6, and the Overlap widget test.
- **Rulings:** none. No files added to `docs/reviews/rulings/` for this story.
- **Unverified:** nothing was built, run or tested during planning. iOS is unbuilt and unverified. Release-build keep rules, the Android 11 package-visibility behaviour of ACTION_VIEW, and the Play sensitive-permission declaration are checked only at the device and release walk.
