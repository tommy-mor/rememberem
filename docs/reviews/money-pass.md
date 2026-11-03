# Money pass

Pricing and marketing for the first Play Store release, built on
[play-store-plan.md](play-store-plan.md). `sid` drafted the offer; `grace`,
`gill`, `sally` and `lena` reviewed it (2026-11-02, commit 83f544e).
Prices of comparable apps and Play's fees come from web pages the agents
fetched. Check them before relying on them. Nobody has measured
willingness to pay.

## The offer

**Free app, with everything included. Optional one-time "Supporter"
purchase, about $5, offered only in Settings and About.**

- **Nothing is gated, now or later.** Capture, records, notes, search,
  trash, practice games and reminders are free. `grace` and `gill` both
  rejected the alternative, a paid "Practice+" unlock. Practice and
  reminders are what turn a saved photo into a remembered name. Charging
  for them would make the person who struggles most with names the one
  who pays, and would leave free users with an address book rather than a
  memory aid. That would hurt word of mouth as well as the north star.
- **Supporter unlocks nothing.** No prompts, no nagging badges, no
  "unlock" wording, and never near capture. A small visible thank-you is
  fine, such as a line in About ("Thank you for supporting Rememberem").
  `grace` and `lena` suggested it so buyers don't feel they paid for
  nothing.
- **Wording (`lena`):**
  - Call it "Supporter" and describe it as a purchase: "One-time purchase
    that supports development. Unlocks nothing."
  - Never "donation" or "gift". Play's payments policy excludes tax-exempt
    donations, so the word risks a policy flag.
  - Refunds follow Play's own process; promise no more than that.
- **Why not paid up front, or a subscription?** A paid app ($3–5) is the
  least code but kills installs and the goodwill of free testers. A
  subscription has no server cost to justify it; sync, the only feature
  that would, doesn't exist.
- **Comparables (`sid`, secondary sources):**

  | App | Model | Price |
  | --- | --- | --- |
  | Dex, Clay | Server-backed personal CRMs | About $10–12/month |
  | AnkiMobile (iOS) | One-time | $24.99 |
  | AnkiDroid (Android) | Free, donations | — |

  No face-and-name memory app with a public price turned up.

### Money (estimates)

- **Fee.** Play's service-fee page, as `lena` fetched it, lists 20% plus a
  5% billing fee for new installs in the US, UK, EEA, Japan and Australia.
  Elsewhere it is 15% on the first $1M a year. A $5 Supporter therefore
  nets about $3.75–4.25 before tax.
- **Running cost.** No server, so nearly nothing.
- **Build cost.** One non-consumable product through `in_app_purchase`,
  plus restore. About a day of work, and none of it until the demand test
  below says it is worth it.

### Privacy cost of billing (`sally`)

- **Exposure is small.** Play Billing adds a no-prompt permission. The
  purchase links the buyer's Google account to Rememberem, but no names,
  photos or notes are involved.
- **Data safety form.** Declare purchase history.
- **Handling the token.** Never send or log purchase tokens. Keep the
  Supporter flag in `settings.json`, not in `memories/`.
- **Hardening.** Don't harden the check. It protects nothing private.

## Before any of this: make the privacy claim true

The obvious listing lead, "nothing leaves your phone", **is false today**
(`sally`, `grace`). Three things can leave the phone:

- **Android backup.** It is on by default, so `memories/` can go to the
  user's Google Drive backup.
- **Dictation.** It may use Google's cloud recogniser.
- **Map tiles.** They come from OpenStreetMap, which sees the IP address
  and the area being viewed.

Fix backup (Play Store plan, blocker 4) and settle speech first. Until
then, use `sally`'s accurate line:

**Update (fix round 1):** Eric kept backup **on** and made it clear in
the app, and dictation now requests on-device recognition. "Nothing leaves
your phone" therefore stays off the listing for good. Use `sally`'s line
below, with backup added: "Photos and notes are stored on your phone, and in
your phone's Google backup if that is on."

> No account, no ads, no analytics. Photos and notes are stored on your
> phone. Voice dictation uses your phone's speech service, and map tiles
> load from OpenStreetMap (you can turn maps off).

Once backup is off and speech is on-device or disclosed, the stronger
line can be: "No account, no ads, no uploads. Your people stay on your
phone."

## Legal must-dos before selling anything (`lena`, not a lawyer)

1. **Payments profile.**
   - The Play payments profile needs a legal name, an address, an email
     and a phone number. The email and phone appear on the listing.
   - Check in the Console whether the postal address is shown publicly.
     If you want your home address off the listing, check before
     enabling sales.
   - Ask an accountant about tax.
2. **Privacy policy (also required for the free release).** Host it on
   ericjorgensen.com. It must state:
   - what is stored: photos, names, notes, location and a contact link;
   - that it stays on the device;
   - that speech may go to Google or Apple;
   - the OpenStreetMap tiles;
   - how backup treats the data;
   - how to delete everything;
   - that the user is responsible for consent when photographing others;
   - that the app is not for children.

   The Data safety form must match it.
3. **Faces of non-users.** Whether a stored portrait counts as biometric
   data under BIPA (Illinois), Texas or Washington law, and whether the
   GDPR household exemption covers the developer as well as the user, are
   questions for a lawyer. The app keeps no face templates; ML Kit only
   finds faces to crop.
4. **OpenStreetMap tile policy.**
   - Attribution must be clearly visible, not hidden behind a toggle, and
     should link to openstreetmap.org/copyright. `street_map.dart:102`
     uses `RichAttributionWidget`, which may collapse behind an icon.
     Check it on a device.
   - The User-Agent is already set.
   - Add a fallback for when tiles fail.
5. **Licences.**
   - Add `showLicensePage` to About.
   - Read the ML Kit terms.
   - Move the NASA test portrait out of release assets.

## Marketing (one person, almost no budget)

**Who first.** Recruit by situation, not by condition (`grace`): "people
who meet a lot of new faces and are bad with names."

- **Good first groups:** new-in-town people, networkers and volunteers,
  church greeters, and adults who meet many people.
- **Wait on teachers.** That means photographing minors. Leave them out
  for now.
- **Pastors and church greeters** only after the ask-first cue (Play
  Store plan, item 11) ships.
- **Prosopagnosia and ADHD communities.** Don't pitch to them as a
  remedy. The face game needs sight, and the app treats nothing. Post
  only where the rules allow, say plainly that you built it, and let
  people find it rather than asking them for money.

**Where.**
- Relevant subreddits and forums, following each one's rules about
  self-promotion.
- Church and community groups, through people you know.
- Your own site and personal network.
- No paid ads.

**What the listing leads with (`gill`).** One promised outcome:
"Remember the people you meet." Make no other claim until the closed test
has measured it.

**Closed test as launch.** Play requires 12 testers for 14 days for a new
personal developer account (confirm in the Console). Recruit them from the
groups above, not only friends. Tell every tester to photograph only
people who agreed. Give each tester a feedback link, then fix what they
report before production. They become the first reviews.

### Two experiments, both inside the privacy limits

Nothing leaves the phone; testers report results themselves.

1. **The Sunday name check (`gill`): does it work?**
   - Day 1: each tester adds 5 new people and writes their names on paper
     outside the app.
   - Day 8: they look at each face and write the name before checking.
   - They report "n of 5" and roughly how many practice games they played.
   - Compare testers who played 3+ games with those who played none. With
     12 people this is a signal, not proof.
2. **Would anyone pay? (`sid`)** One question on the feedback form: "Would
   you pay $5 once to support this? Yes / Maybe / No."
   - Fewer than about a third answering yes or maybe means ship free and
     skip billing.
   - Stated intent overstates real purchases, so treat yes as a ceiling.

**The feedback form and waitlist (`sally`).**
- Collect only an optional email and a message.
- Say not to include other people's details.
- No trackers.
- State how long replies are kept and how to be removed.

## Next actions (in order)

1. Fix the privacy gaps first: backup, and the speech decision. They are
   also Play Store plan blockers.
2. Publish the privacy policy and fill in the Data safety form to match.
3. Run the closed test with recruited testers, the Sunday name check and
   the one pay question.
4. Ship to production free.
5. Add Supporter only if the pay question clears its bar, worded as above.
