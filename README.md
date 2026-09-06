# Notes

A dark, minimal notes app for iPhone, sold on the App Store as **Matte** (the
Home Screen icon says Notes). Black and white, dark mode only. Write, edit,
delete, search, checklists, and one extra: pin a note to the Lock Screen.
Notes sync between your own devices through iCloud; there are no accounts and
no server.

The spec this was built from is `NOTES_APP_SPEC.md`.

## Layout

```
project.yml                 xcodegen spec: app, widget, tests
Notes/                      the app
├── NotesApp.swift          @main, model container, deep link
├── Models/                 Note (SwiftData) and NoteStore (create, trash, delete, pin)
├── Views/                  list, row, editor, Trash, UITextView wrapper
├── Logic/                  Checklist, NoteText, DateFormat, Trash, PinStore, RecentStore, the Live Activity
├── Theme/                  colours, fonts, spacing
└── Assets.xcassets/        AppIcon (generated), launch background
NotesWidget/                the Live Activity and the widgets (one extension)
NotesTests/                 XCTest, runs on the simulator
AppStore/                   listing copy and the submission checklist
docs/                       privacy policy and support pages (GitHub Pages)
scripts/make-icon.py        draws AppIcon.png from the numbers in the spec
```

Identifiers:

| What | Value |
|---|---|
| App | `com.cj.notes` |
| Widget | `com.cj.notes.widget` |
| App Group | `group.com.cj.notes` |
| iCloud container | `iCloud.com.cj.notes` |
| URL scheme | `notes://note/<uuid>` |

## Build

Needs Xcode 15 or newer and [xcodegen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). Nothing else.

```bash
xcodegen generate
open Notes.xcodeproj
```

Pick the `Notes` scheme, pick your iPhone, press Run. The first run on a
device makes Xcode register the App Group and the iCloud container with your
developer account; that happens on its own with automatic signing.

Tests: `⌘U` in Xcode, or

```bash
xcodebuild test -project Notes.xcodeproj -scheme Notes \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Free developer account

A free account cannot carry the iCloud or push entitlements. Delete the
`com.apple.developer.icloud-*` and `aps-environment` keys under
`entitlements.properties` in `project.yml`, regenerate, and the app builds
and runs with local storage only. The code falls back to a local store
when CloudKit is unavailable, so nothing else changes. Installs from a free
account last seven days.

## The Lock Screen pin

Pin a note (long-press it in the list, or the pin in the editor) and it is
on the Lock Screen at once, as a Live Activity: the card under the clock,
and the Dynamic Island on phones that have one. The card is the title, and
for a checklist the count at the right (`0/4`); the items themselves stay
in the note. A plain note shows its first line under the title. A body line
that ends in a number, like `Water 3` or `Pushups 20`, is a counter: it
gets a + on the card, and a tap makes it `Water 4` in the note. (A label
with a digit in it, such as `Room 4`, is left alone; the card carries three
counters at most.) Tapping the card opens the note. Pinning another note
replaces it; unpinning or deleting removes it. The widget draws the same
card.

iOS ends every Live Activity after eight hours, and a user can swipe one
away. The app puts the pinned note back each time it comes to the
foreground, so it is there whenever the app has been used that day. That is
the honest limit of the mechanism: keeping it up indefinitely would need a
push server, and this app has none.

The widget is the permanent alternative. Anyone who adds it once (long-press
the Lock Screen, Customize, Lock Screen, tap under the clock, add Notes)
sees the pinned note there for as long as it is pinned: the rectangle is
the card and the inline slot one line. The app writes a
small record (id, title, preview, counters, count) to the App Group's `UserDefaults`
and reloads WidgetKit whenever the pin changes; the widget only reads that.

## The widgets

Three widgets, all in the system's colours on the system's widget
background, so they look like the phone's own: translucent on the Home
Screen, vibrant on the Lock Screen.

- **Notes.** Round, on the Lock Screen, it is the app's logo (`LogoMark`,
  the icon's three bars drawn from the numbers in `scripts/make-icon.py`),
  and a tap opens the app. Medium and large, on the Home Screen, it lists
  the latest notes, three or seven, the pinned one first, each a link to
  itself, with the pencil at the side. The app writes the list
  (`RecentStore`, in the App Group) after every save and on each
  foreground, blank notes left out; the widget only reads it.
- **New note.** Round, on the Lock Screen, or small, on the Home Screen: the
  pencil. One tap opens the app on a fresh note (`notes://new`).
- **Pinned note.** The Lock Screen rectangle and inline line, and a small
  Home Screen card, showing the pinned note; described above.

## Search and Siri

Every note that is not in the Trash is in the iPhone's own search index
(Core Spotlight), so it turns up when the user searches from the Home
Screen; tapping the result opens it. The index is rebuilt on each
foreground, which also covers notes that iCloud brought in or took away.
It lives on the phone; nothing leaves it.

Three App Intents work from Siri and the Shortcuts app without setup:
"New note in Matte", "Add to Groceries in Matte" (Siri asks what to add,
and it lands as an open item at the end of the note), and "Pin Groceries
in Matte" (which opens the app, since a Live Activity can only be started
from the foreground). "In Notes" works too; `INAlternativeAppNames` in
`project.yml` adds Matte because Apple's own Notes owns the plain word.
Siri learns the note titles from `NoteQuery.suggestedEntities`, refreshed
on each foreground.

## Ship

1. **App Store Connect**: create the app record with bundle id `com.cj.notes`
   (Apps → + → New App). The widget needs no record of its own.
2. **Archive**: in Xcode, Product → Archive with "Any iOS Device" selected.
   Release builds use automatic signing, same as Debug.
3. **Upload**: in the Organizer, Distribute App → TestFlight & App Store →
   Upload. Xcode manages the profiles.
4. **TestFlight**: in App Store Connect, under TestFlight, add testers by
   email. Internal testers (your team) need no review. External testers go
   through a short review once, a day or two. They install through the
   TestFlight app and later builds update on their own.
5. **App Store**: when it is stable, follow `AppStore/SUBMISSION.md` top to
   bottom. `AppStore/LISTING.md` has every field the form asks for, and the
   privacy and support pages it links are in `docs/`.

Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
before each upload; App Store Connect refuses a build number it has seen.

## What is and is not built

Everything in the spec's acceptance list is implemented: autosave, the
first-line title, search with white-on-black highlights, swipe to delete
(into a Trash, behind the trash glyph beside the title, where a tap puts a
note back, a swipe deletes it for good, and anything left is gone after
thirty days), checklists (button, tap the circle to toggle, Return
continues, Return on an empty item ends), list previews, single pin, the
Live Activity (the spec's stretch goal), the widget in all three families,
the deep link, CloudKit sync, and the app icon. Two things past the spec:
every screen follows the text size set in Settings, and the checklist
markers, `□` and `■` in the text, are drawn as circles by the editor's own
layout fragments, so the note stays plain text. On an iPhone with Apple
Intelligence, iOS's Writing Tools (Proofread, Rewrite, Summarize) work
inline in the editor; the editor runs on TextKit 2 for that, and hands
Writing Tools the marker ranges to leave alone, so a rewritten checklist
is still a checklist.

Two places iOS decides, not the spec: a swipe action paints its label white
whatever the tint and draws it in its own shape, so the swipe-to-delete is
a dark grey circle with a white trash glyph rather than the spec's white
block with black text; the widget's text uses the Lock Screen's own
rendering, so it is always white on the wallpaper; and the Live Activity
sits on the system's card material with the system's text colours, not
the app's black, so it looks like every other card under the clock.

Not built, on purpose: folders, tags, colours, rich text, attachments,
sharing, accounts, and light mode.
