# Notes

A dark, minimal notes app for iPhone, called **Matte** on the App Store and
on the Home Screen. Black and white, dark mode only. Write, edit,
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
and the Dynamic Island on phones that have one (compact, it is the pin
alone, with a checklist's count beside it; the card is a long-press away,
so the island stays as small as other apps'). The card is the title, and
for a checklist the count at the right (`0/4`); the items themselves stay
in the note. A plain note shows its first line under the title; a long
one (two body lines or more, or one past sixty characters), on an iPhone
with Apple Intelligence, gets instead a one-line summary of what it is
about, from Apple's on-device model (`LockScreenSummary`, cached by text
so a note is summarised once; the first line stands in until the model
answers, and the answer is used only if that note is still pinned and
unchanged; `LockScreenSummary.cached` puts it back each time the record is
rebuilt, which happens on every save and every foreground, or the note's
first line would take its place again). A body line
that ends in a number, like `Water 3` or `Pushups 20`, is a counter: it
gets a + on the card, and a tap on the + makes it `Water 4` in the note.
Only the + counts: the rest of the row is the card, so a tap beside it
opens the note. A counter line has its own row, so it is not shown as the
preview as well. (A label with a digit in it, such as `Room 4`, is left
alone; the card carries three counters at most.) Tapping the card opens the note. Pinning another note
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

## What is copied out of a note

A note's text lives in SwiftData, and in the user's own CloudKit private
database when they are signed in (`text` carries
`@Attribute(.allowsCloudEncryption)`, so it is end-to-end under Advanced
Data Protection rather than readable to Apple). Four places hold a copy of
part of it, and each is bounded on purpose: the App Group record the
widgets read (a title and `NoteText.previewLimit` characters of preview,
for the eight most recent notes), the Live Activity's content state (the
same, and it has to fit in the four kilobytes iOS allows), the phone's own
Spotlight index, and a scheduled notification's title and line. Deleting a
note takes all four with it, the delivered notification included. The
records are written with hand-rolled `init(from:)` decoders that tolerate a
missing field, so a record written by one version is still readable by the
next; without that, adding a field would blank the widget until the app
was next opened.

## The widgets

Three widgets, all in the system's colours. On the Home Screen they sit
on a solid ground, white in light mode and black in dark, never
translucent, so the wallpaper never washes them out; on the Lock Screen
they sit on the system's accessory pill and are accentable, so the tinted
and vibrant modes keep them legible.

- **Recent notes.** Round, on the Lock Screen, it is the app's logo
  (`LogoMark`, the icon's three bars drawn from the numbers in
  `scripts/make-icon.py`), and a tap opens the app. Small, on the Home
  Screen, it is the pinned note or the latest one. Medium and large, it
  lists the latest notes, four or nine, the pinned one first, each a link
  to itself, with the pencil in the corner. The app writes the list
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

Search in the app matches letters as they are typed, at once. When they
match nothing, on an iPhone with Apple Intelligence (iOS 26), the question
goes to Apple's on-device model a moment after typing stops
(`NoteFinder`): it reads the notes (forty at most, the first 240
characters of each) and answers, so "when is the dentist" finds "call the
dentist tuesday". The answer is the line above the results, in place of
the count, and the notes it came from are the rows. The model runs only
on a miss; typing again cancels it; nothing leaves the phone. Elsewhere a
miss says "No matches." as before.

Five App Intents work from Siri and the Shortcuts app without setup:
"New note in Matte", "Add to Groceries in Matte" (Siri asks what to add,
and it lands as an open item at the end of the note), "Pin Groceries in
Matte" (which opens the app, since a Live Activity can only be started
from the foreground), "What's on Groceries in Matte" (Siri reads the open
items, or a plain note's first lines: `NoteText.spoken`), and "Tick
something off Groceries in Matte" (Siri asks which; the first open item
that is or contains the words is marked done: `Checklist.ticking`).
Siri learns the note titles from `NoteQuery.suggestedEntities`, refreshed
on each foreground.

## Ship

1. **App Store Connect**: create the app record with bundle id `com.cj.notes`
   (Apps → + → New App). The widget needs no record of its own.
2. **Archive**: in Xcode, Product → Archive with "Any iOS Device" selected.
   Release builds use automatic signing, same as Debug.
3. **Upload**: in the Organizer, Distribute App → TestFlight & App Store →
   Upload. Xcode manages the profiles. Both targets carry a
   `PrivacyInfo.xcprivacy` (no tracking, nothing collected, `UserDefaults`
   declared with reasons CA92.1 and 1C8F.1 for the App Group record), which
   App Store Connect checks at upload.
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
layout fragments, so the note stays plain text. One thing changed from the
spec: a list row is the title and the preview, with no time in front, and
the list is in order of use (the last note opened or edited at the top,
after the pinned one; `openedAt` on the note, set when the editor shows
it), so a row needs no date to explain its place. The time moved into the
editor, one muted line under the bar: `Today at 9:14 AM`, `Thursday at
9:14 AM`, `Aug 28 at 9:14 AM`. The Trash keeps a date on its rows, the day
the note went in. On an iPhone with Apple
Intelligence, iOS's Writing Tools (Proofread, Rewrite, Summarize) work
inline in the editor; the editor runs on TextKit 2 for that, and hands
Writing Tools the marker ranges to leave alone, so a rewritten checklist
is still a checklist. The sparkle in the editor bar is a menu. Make a
list: the plain lines under the title become items, with Apple's on-device
model (`ListMaker`, the Foundation Models framework, on iOS 26 with Apple
Intelligence) or, anywhere else, with `Checklist.split` on commas, "and",
and line breaks. Tidy up makes each line read cleanly, line for line: the
model, where there is one, fixes spelling, punctuation and filler, and
every line then gets the careful typist's pass whatever the phone
(`NoteText.tidied`: capitals, no space before a comma, one after). The
checklist markers are taken off before the model sees the lines and put
back after (`Checklist.bareLines`, `restoringMarkers`), items stay
fragments with no full stop, and a line the model rewrote or ran together
with its neighbour keeps its original (`ModelGuard.tidyKeeps`, tested), so
lines are never merged. With the model there are three more (`OnDevice`):
Add a title, which reads the note and puts a few words on a new first
line; Sort the list, for a checklist of three items or more, which has the
model label each item with its kind (dairy, hardware, calls) and puts the
items of a kind together in the order the kinds first appear
(`ListSorter.order`, tested: a missing or repeated number means no change,
and so does a list that changed under the spinner; `Checklist.items`,
`reordering`); and Where did I leave off, below. Ticks and plain
lines stay where they are. Each is one edit, so a shake takes it back.
Reminders finds the dates and times in the note on any iPhone:
`DateSpotter` (tested) reads each line, and each part of a line between
slashes or semicolons, for a weekday, today or tomorrow, a time, "in
twenty minutes", "on the 1st" or "3 October", and takes the date words
out for the title; with the model, its findings are merged in too
(`OnDevice.reminders`, told the coming week so "tuesday" lands on a date;
`ReminderStamp` parses what it writes; `Reminders.find` joins the two).
They show on a
sheet; one tap puts the chosen ones in the iPhone's Reminders app through
EventKit (`Reminders.add`), asked at that tap and never before, or, with
"Notify me", a one-time local notification from the app at the time, the
note's title and the line, a tap opening the note (`Notify`,
`NotificationRouter`; `NotifyPlan`, tested, names each one per note and
line and finds the ones a later edit no longer backs, which are cancelled
on save; the Trash cancels a note's). No repeats or snooze; those are the
Reminders app's. Notifications are asked for at that tap. The note is
not changed. Holding the
pencil in the list dictates a note: iOS's speech recognition with
on-device recognition required (`SpeechListener`; where the language has
none, the app does not listen), the words shown as they are heard, and
on Stop the model turns them into a note with a title, spelling and
punctuation fixed, and a checklist where a list was spoken
(`OnDevice.cleaned`, `Dictation.compose`); without a model the note is
the words as spoken, first sentence as the title (`Dictation.plain`).
The microphone and speech recognition are asked for at that first hold.
Either way the text stays on the phone.

How the model is driven, the same for every task: an instruction with two
worked examples, since this is a small model and examples do more than
rules; greedy sampling, so the same note gives the same answer and the
model keeps to what it was given; output shaped by `@Generable` and
`@Guide` (a regex on a reminder's date, a cap on the notes a search may
name); one prewarmed session per launch, so the first tap is not the slow
one; and a check on what comes back (`ModelGuard`, tested) so only what
the model got right is applied: an item or a title in words that are not
in the note is dropped, a tidied line that changed length by more than
forty percent keeps its original, a dictation that lost half its words is
kept as spoken. When an action changes nothing, the date line under the
bar says why for a moment.

Two things reach across time, both on the on-device model and both quiet.
"Where did I leave off?": opening a plain note with three body lines or
more that was last opened over a day ago (`openedAt`), the line under the
bar becomes a brief in the note's own words, "Decided: October, $3,000
budget. Open: pick a hotel. Next: compare the two near the station."
(`OnDevice.brief`, `Brief`, tested; every part must be in the note's words
or it is dropped; cached by text), gone at a tap or a keystroke, and
there on demand in the sparkle menu. "You've thought about this before":
2.5 seconds after typing stops in a note with eight content words or more,
the other notes are ranked by shared words (`Recall.candidates`, tested;
three shared words at least, five candidates at most, so most pauses cost
nothing) and the model is asked whether one of them says something that
bears on what is being written (`OnDevice.recall`; what it said must be
in that note's words). If so, a line under the bar: "You wrote about this
in Standing desk: 'standing hurt my knee for a week'"; a tap asks whether
to open that note or move what was written here into it
(`NoteStore.move`, `NoteText.appending`: after a blank line, the
placeholder title left behind, this note to the Trash); each older note
comes up once per sitting. The brief never says a thing twice: an open
item that is the next step, or a decided item that is also open, goes
(`Brief.same`).

Two places iOS decides, not the spec: a swipe action paints its label white
whatever the tint and draws it in its own shape, so the swipe-to-delete is
a dark grey circle with a white trash glyph rather than the spec's white
block with black text; the widget's text uses the Lock Screen's own
rendering, so it is always white on the wallpaper; and the Live Activity
takes iOS's own material rather than a tint of ours
(`activityBackgroundTint(nil)`), which is the frosted card every other
app's Live Activity gets, so it follows the wallpaper and the Lock
Screen's own settings instead of sitting on them as a black slab.

Not built, on purpose: folders, tags, colours, rich text, attachments,
sharing, accounts, and light mode.
