# App Store listing

Everything App Store Connect asks for, in the order its form asks. Paste
from here. Character limits are Apple's; every field below is inside them.

## App name (30 characters)

**Matte**. Fallback if App Store Connect refuses it: **Matte Notes**.

"Notes" alone is taken on the App Store, which is why the store name is
something else. The name on the Home Screen stays "Notes" regardless: that
is `CFBundleDisplayName` in `project.yml`, and Apple allows the two to differ.
A search of the store in September 2026 found no app named Matte; the Name
field is the final check.

## Subtitle (30 characters)

**Smart notes on the Lock Screen** (30 characters exactly)

Fallback: **Notes, pinned to Lock Screen**

Apple's names (Apple Intelligence, Siri, Writing Tools) stay out of the
name and subtitle, where Apple's trademark rules are strict, and go in the
promotional text and description, where naming a feature the app supports
is allowed.

## Category

Primary: Productivity. Secondary: Utilities.

## Promotional text (170 characters, editable without a new build)

Apple Intelligence where it helps: Writing Tools in the note, Siri for your lists, a tap that turns a jumble into a checklist. And one note, always on your Lock Screen.

## Description (4000 characters)

Matte is a notes app with nothing in the way, and Apple Intelligence where it helps.

It is black and white and dark only. Open it and write. The first line is the title. Everything saves as you type; there is no save button and nothing to set up.

APPLE INTELLIGENCE, WHERE IT HELPS
On an iPhone with Apple Intelligence, the smart parts are built in and run on the phone. Select text and use Writing Tools to proofread, rewrite, or summarize, right in the note; a checklist comes through intact. Tap Make a list and a paragraph or a dictated jumble ("milk eggs and call the dentist tuesday") becomes checklist items, one per task, in your own words, using Apple's on-device model. Add a title reads the note and gives it one. Tidy up makes every line read cleanly, in your own words. Sort the list groups a checklist by kind, dairy with dairy and errands with errands. Reminders finds the dates and times in a note ("dentist tuesday 3pm") and, with one tap, puts them in your Reminders app or sets a notification from Matte that opens the note at the time. Hold the pencil and speak: the note lands with a title, clean spelling, and a checklist where you spoke a list, with speech turned into text on the phone. Come back to a note after a day and it tells you where you left off: what you decided, what is open, what is next. And while you write, if an older note says something you should remember, it comes up under the bar. Nothing you write or say leaves the phone for any of it. On other iPhones, Make a list, Tidy up and Reminders still work, by plain rules on the phone.

SIRI, NO SETUP
"Add milk to Groceries in Matte". "What's on Groceries in Matte", and Siri reads what is left. "Tick milk off Groceries in Matte". "New note in Matte". "Pin Groceries in Matte". Siri and the Shortcuts app do all five, hands free. Your notes also show up when you search your iPhone from the Home Screen.

PIN ONE NOTE TO YOUR LOCK SCREEN
Long-press a note and pin it. It appears on your Lock Screen right away, no setup, so the thing you must not forget is the first thing you see when you pick up the phone. A checklist shows how many items are done; a long note shows a one-line summary of what it is about, written on the phone by Apple's on-device model where there is one. Write "Water 0" and it becomes a counter with a + on your Lock Screen. Tap the card and the note opens. Pin a different note and it takes its place. Add the Notes widget once and the pin stays put for good.

ON YOUR HOME SCREEN
A widget with your latest notes and a pencil. Tap a note to open it, tap the pencil to start one.

CHECKLISTS INSIDE YOUR NOTES
Turn any line into a checklist item with one tap. Tick items off in the note, and the list shows how far along you are: "2/5 done · milk, eggs".

SEARCH EVERYTHING
Search matches titles and bodies as you type, with every match highlighted. On an iPhone with Apple Intelligence, a search that matches nothing becomes a question: "when is the dentist" finds the note that says "call the dentist tuesday", answered on the phone by Apple's on-device model.

A TRASH, NOT A WARNING
Swipe to delete, no confirmation. The note waits in the Trash for 30 days, where one tap puts it back.

SYNCS THROUGH YOUR ICLOUD
Your notes appear on all your iPhones, through your own iCloud. There is no account to create, no server, and no sign-in.

NOTHING COLLECTED
No analytics, no tracking, no ads, no third-party code. The developer cannot read your notes. See the privacy policy: it fits on one screen.

WHAT IT DOES NOT DO
No folders, tags, colours, fonts, images, or sharing. No light mode. It is for the notes you write in a hurry and need to see again.

Requires iOS 17 or later.

## Keywords (100 characters, comma separated, no spaces)

notes,lock screen,widget,checklist,minimal,dark,matte,siri,writing tools,ai,todo,notepad,icloud

## URLs

| Field | Value |
|---|---|
| Support URL | https://chetanjon.github.io/notes/ |
| Marketing URL (optional) | https://chetanjon.github.io/notes/ |
| Privacy Policy URL | https://chetanjon.github.io/notes/privacy.html |

Both pages are in `docs/` in this repo. They go live once GitHub Pages is on:
repository Settings → Pages → Source: Deploy from a branch → `main`, `/docs` → Save.

## Version information

| Field | Value |
|---|---|
| Version | 1.0.0 (must match `MARKETING_VERSION` in `project.yml`) |
| Copyright | 2026 Chetan Jonnalagadda |
| What's New (first release) | First release. |

## Age rating

Answer "None" to every question in the questionnaire. Result: 4+.

## App Privacy (the nutrition label)

Choose **Data Not Collected**.

Why that is the truthful answer: notes live on the device and in the user's
own CloudKit private database, which the developer cannot read. Apple's
definition of "collected" is data sent off the device to the developer or a
third party in a way they can access. Nothing in the app does that. There
are no analytics, no crash reporting SDKs, no ads, no identifiers.

## App Review information

| Field | Value |
|---|---|
| Sign-in required | No |
| Contact | your name, phone, and email (Apple contacts you here if the review has a question) |
| Notes for the reviewer | see below |

Notes for the reviewer, paste as is:

> Matte is a local-first notes app; its icon on the Home Screen is labelled
> "Notes". No account is needed. To test the Lock Screen feature: create a
> note, long-press it in the list, choose "Pin to Lock Screen", and lock the
> device: the note shows as a Live Activity under the clock. Three widgets
> are listed under Notes in the widget gallery (long-press the Lock Screen →
> Customize → Lock Screen → tap under the clock): Notes (the app's logo,
> opens the app; on the Home Screen, the latest notes), New note (a pencil,
> starts a note), and Pinned note (the pinned note, permanently). Siri: say
> "Add milk to Groceries in Matte", "What's on Groceries in Matte", or
> "Tick something off Groceries in Matte" after opening the app once, so
> Siri knows the note titles. Apple Intelligence: Writing Tools work inline in the
> editor, and the sparkle button in the editor bar ("Make a list") turns the
> note's plain lines into checklist items with the on-device model on an
> iPhone with Apple Intelligence, or by splitting on commas and line breaks
> on any other iPhone. The sparkle is a menu: "Tidy up" and "Reminders"
> work on any iPhone, "Add a title" and "Sort the list" need the model
> ("Reminders" asks for Reminders access when its Add button is tapped, or for
> notification permission when "Notify me" is tapped, which schedules a
> local notification that opens the note). Holding the pencil in the list
> dictates a note; it asks for the microphone and speech recognition, and
> requires on-device recognition, so no audio leaves the phone. Those are
> the app's only permission prompts. Deleted
> notes wait in the Trash, behind the trash
> glyph beside the title, for 30 days. iCloud sync uses the CloudKit private
> database and needs a device signed into iCloud; it is optional and the
> app works without it.

## Screenshots

Required: one set for the 6.9-inch iPhone display. Apple scales it to the
smaller sizes. Sizes it accepts: 1320 × 2868 or 1290 × 2796 pixels, portrait.

How to take them: in Xcode pick an iPhone 17 Pro Max (or 16 Pro Max)
simulator, run the app, set up each screen, press ⌘S in Simulator. The PNG
lands on the Desktop at the right size. No device frame is needed and none
is added; the black app on a black background is the look.

Take these five, in this order (the first two do most of the selling):

1. **The list** with four or five notes, one pinned. Titles that read like
   real life: "Walking app v1 scope", "Groceries" (a checklist, showing
   "1/4 done · eggs, milk"), "Call amma re: Sunday", "Book title ideas".
2. **The Lock Screen** on a real phone: the pinned note's card under the
   clock, and the round Notes and New note widgets beside the clock. (Lock
   Screen widgets and Live Activities do not render in the simulator's Lock
   Screen; a real-device screenshot of a 6.9-inch phone is the right size.)
   Pick a wallpaper with some texture so the card's see-through look shows.
3. **A checklist** open in the editor, two items ticked, the circles
   showing.
4. **The Home Screen** with the medium Notes widget over the wallpaper,
   three notes listed and the pencil at the side.
5. **Search** with a query typed and matches highlighted.

Optional: a caption above each. Keep them short and in the app's voice:
"Nothing in the way." / "One note, always in sight." / "Checklists, inline."
/ "Your notes, at home." / "Find it fast."
