# Notes

A dark, minimal notes app for iPhone. Black and white, dark mode only. Write,
edit, delete, search, checklists, and one extra: pin a note to the Lock Screen.
Notes sync between your own devices through iCloud; there are no accounts and
no server.

The spec this was built from is `NOTES_APP_SPEC.md`.

## Layout

```
project.yml                 xcodegen spec: app, widget, tests
Notes/                      the app
├── NotesApp.swift          @main, model container, deep link
├── Models/                 Note (SwiftData) and NoteStore (create, delete, pin)
├── Views/                  list, row, editor, UITextView wrapper
├── Logic/                  Checklist, NoteText, DateFormat, PinStore, the Live Activity
├── Theme/                  colours, fonts, spacing
└── Assets.xcassets/        AppIcon (generated), launch background
NotesWidget/                the Live Activity and the widget (one extension)
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
and the Dynamic Island on phones that have one. A checklist shows its open
items one to a row, and tapping a row ticks it, right there on the Lock
Screen, through a `LiveActivityIntent` that runs in the app. A body line
that ends in a number, like `Water 3` or `Pushups 20`, is a counter: it
gets a + on the Lock Screen, and a tap makes it `Water 4` in the note. (A
label with a digit in it, such as `Room 4`, is left alone.) Tapping the
title opens the note. Pinning another note replaces it; unpinning or
deleting removes it. The widget draws the same rows and its taps do the
same.

iOS ends every Live Activity after eight hours, and a user can swipe one
away. The app puts the pinned note back each time it comes to the
foreground, so it is there whenever the app has been used that day. That is
the honest limit of the mechanism: keeping it up indefinitely would need a
push server, and this app has none.

The widget is the permanent alternative. Anyone who adds it once (long-press
the Lock Screen, Customize, Lock Screen, tap under the clock, add Notes)
sees the pinned note there for as long as it is pinned. The app writes a
small record (id, title, preview, date) to the App Group's `UserDefaults`
and reloads WidgetKit whenever the pin changes; the widget only reads that.

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
first-line title, search with white-on-black highlights, swipe to delete,
checklists (button, tap to toggle, Return continues, Return on an empty item
ends), list previews, single pin, the Live Activity (the spec's stretch
goal), the widget in all three families, the deep link, CloudKit sync, and
the app icon.

Two places iOS decides, not the spec: the swipe-to-delete block is as wide
as the system makes it (the spec asks for 88pt), and the widget's text uses
the Lock Screen's own rendering, so it is always white on the wallpaper.

Not built, on purpose: folders, tags, colours, rich text, attachments,
sharing, accounts, and light mode.
