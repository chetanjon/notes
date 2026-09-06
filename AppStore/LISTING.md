# App Store listing

Everything App Store Connect asks for, in the order its form asks. Paste
from here. Character limits are Apple's; every field below is inside them.

## App name (30 characters)

"Notes" alone is taken on the App Store, so the store name has to be
something else. The name on the Home Screen stays "Notes" regardless: that
is `CFBundleDisplayName` in `project.yml`, and Apple allows the two to differ.

Pick one that is free when you type it. Candidates: **Noir Notes**,
**Plain Notes**, **Pinned Notes**, or your own name followed by Notes.

## Subtitle (30 characters)

Recommended: **Pinned to your Lock Screen**

Fallback: **Minimal notes, Lock Screen**

## Category

Primary: Productivity. Secondary: Utilities.

## Promotional text (170 characters, editable without a new build)

The notes app that stays out of the way. Pure black, no clutter, and the one note you must not forget sits on your Lock Screen.

## Description (4000 characters)

A notes app with nothing in the way.

Notes is black and white and dark only. Open it and write. The first line is the title. Everything saves as you type; there is no save button and nothing to set up.

PIN ONE NOTE TO YOUR LOCK SCREEN
Long-press a note and pin it. It appears on your Lock Screen right away, no setup, so the thing you must not forget is the first thing you see when you pick up the phone. A checklist shows how many items are done. Write "Water 0" and it becomes a counter with a + on your Lock Screen. Tap the card and the note opens. Pin a different note and it takes its place. Add the Notes widget once and the pin stays put for good.

CHECKLISTS INSIDE YOUR NOTES
Turn any line into a checklist item with one tap. Tick items off in the note, and the list shows how far along you are: "2/5 done · milk, eggs".

SEARCH EVERYTHING
Search matches titles and bodies as you type, with every match highlighted.

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

notes,lock screen,widget,checklist,minimal,dark,black,quick notes,notepad,todo,memo,icloud

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

> Notes is a local-first notes app. No account is needed. To test the Lock
> Screen feature: create a note, long-press it in the list, choose "Pin to
> Lock Screen", and lock the device: the note shows as a Live Activity
> under the clock. The Notes widget (long-press the Lock Screen → Customize
> → Lock Screen → tap under the clock → Notes) shows the same note
> permanently. iCloud sync uses the CloudKit private database and needs a
> device signed into iCloud; it is optional and the app works without it.

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
2. **The Lock Screen** with the widget showing the pinned note. Take this on
   a real phone (Lock Screen widgets do not render in the simulator's Lock
   Screen); a real-device screenshot of a 6.9-inch phone is the right size.
3. **A checklist** open in the editor, two items ticked.
4. **Search** with a query typed and matches highlighted.
5. **A plain note** open in the editor, cursor at the end, keyboard up.

Optional: a caption above each. Keep them short and in the app's voice:
"Nothing in the way." / "One note, always in sight." / "Checklists, inline."
/ "Find it fast." / "Just write."
