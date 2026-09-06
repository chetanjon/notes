import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity: the pinned note, on the Lock Screen at once

/// Drawn from the attributes the app passed when it started the activity.
/// Never touches the store or the App Group.
struct PinnedNoteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PinnedNoteAttributes.self) { context in
            LockScreenPinView(noteID: context.attributes.noteID, state: context.state)
                .widgetURL(context.attributes.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.fg)
                        .padding(.leading, 6)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PinnedCardView(
                        title: context.state.title, preview: context.state.preview,
                        counters: context.state.counters, isChecklist: context.state.isChecklist,
                        done: context.state.done, total: context.state.total,
                        showsPin: false, noteID: context.attributes.noteID)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "pin.fill")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.fg)
            } compactTrailing: {
                Text(context.state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.fg)
            }
            .widgetURL(context.attributes.url)
            .keylineTint(Theme.fg)
        }
    }
}

/// The card under the clock, on the system's own card material so it
/// matches every other app's, with the system's text colours on it.
struct LockScreenPinView: View {
    let noteID: UUID
    let state: PinnedNoteAttributes.ContentState

    var body: some View {
        PinnedCardView(
            title: state.title, preview: state.preview, counters: state.counters,
            isChecklist: state.isChecklist, done: state.done, total: state.total,
            showsPin: true, noteID: noteID, adaptive: true)
        .padding(12)
    }
}

/// The pinned note as one card: the title, with a checklist's count at the
/// right; a plain note's first line under it; then its counters, each with
/// a +. A checklist's items stay in the note. Shared by the Live Activity
/// and the widgets, in the system's colours or the app's. Text styles, so
/// it follows the phone's text size.
///
/// With a `noteID`, counter rows are buttons. The intent is a
/// `LiveActivityIntent`, which iOS runs in the app process whichever
/// surface the button is on, so a tap reaches the store from the widget
/// too.
struct PinnedCardView: View {
    let title: String
    let preview: String
    let counters: [PinnedCounter]
    let isChecklist: Bool
    let done: Int
    let total: Int
    var showsPin: Bool
    var noteID: UUID? = nil
    /// On the Lock Screen card the system draws the background, so the
    /// text takes the system's colours and reads on any wallpaper. Off,
    /// the app's white and grey on black.
    var adaptive = false

    private var fg: AnyShapeStyle { adaptive ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.fg) }
    private var muted: AnyShapeStyle { adaptive ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.muted) }

    private var allDone: Bool { isChecklist && total > 0 && done == total }

    var body: some View {
        VStack(alignment: .leading, spacing: adaptive ? 2 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(fg)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isChecklist, total > 0 {
                    Text("\(done)/\(total)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(muted)
                }
                if showsPin {
                    Image(systemName: "pin.fill")
                        .font(.footnote)
                        .foregroundStyle(muted)
                }
            }
            if allDone {
                Text("All done")
                    .font(.subheadline)
                    .foregroundStyle(muted)
            } else if !isChecklist, !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            ForEach(counters, id: \.line) { counter in
                if let noteID {
                    Button(intent: StepCounterIntent(noteID: noteID, line: counter.line)) {
                        counterRow(counter)
                    }
                    .buttonStyle(.plain)
                } else {
                    counterRow(counter)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Water  3  +": the number in monospaced digits, the plus at the edge.
    private func counterRow(_ counter: PinnedCounter) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(counter.label)
                .font(.subheadline)
                .foregroundStyle(fg)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(counter.value)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(fg)
            Image(systemName: "plus")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(fg)
                .frame(width: 20)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Pinned note widget: the permanent option, for anyone who adds it

/// Reads the record the app wrote to the App Group; never touches the store.
struct PinnedEntry: TimelineEntry {
    let date: Date
    let pinned: PinStore.Pinned?
}

struct PinnedProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedEntry {
        PinnedEntry(date: .now, pinned: PinStore.Pinned(
            id: UUID(), title: "Groceries", preview: "1/4 · eggs, milk, rice", updatedAt: .now,
            isChecklist: true, done: 1, total: 4))
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedEntry) -> Void) {
        completion(PinnedEntry(date: .now, pinned: context.isPreview ? placeholder(in: context).pinned : PinStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedEntry>) -> Void) {
        completion(Timeline(entries: [PinnedEntry(date: .now, pinned: PinStore.read())], policy: .never))
    }
}

/// The pinned card in the system's colours on the system's widget
/// background: vibrant on the Lock Screen, translucent on the Home Screen.
struct NotesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PinnedEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inline
            case .accessoryRectangular:
                rectangular
            default:
                small
            }
        }
        .widgetURL(entry.pinned?.url)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inline: some View {
        Group {
            if let pinned = entry.pinned {
                Text(pinned.preview.isEmpty ? pinned.title : "\(pinned.title) · \(pinned.preview)")
            } else {
                Text("Nothing pinned")
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let pinned = entry.pinned {
                PinnedCardView(
                    title: pinned.title, preview: pinned.preview, counters: pinned.counters,
                    isChecklist: pinned.isChecklist, done: pinned.done, total: pinned.total,
                    showsPin: false, noteID: pinned.id, adaptive: true)
            } else {
                Text("Nothing pinned")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Long-press a note to pin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pinned = entry.pinned {
                PinnedCardView(
                    title: pinned.title, preview: pinned.preview, counters: pinned.counters,
                    isChecklist: pinned.isChecklist, done: pinned.done, total: pinned.total,
                    showsPin: false, noteID: pinned.id, adaptive: true)
            } else {
                Text("Nothing pinned")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Long-press a note to pin")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct NotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NotesPinned", provider: PinnedProvider()) { entry in
            NotesWidgetView(entry: entry)
        }
        .configurationDisplayName("Pinned note")
        .description("Shows the note you pinned.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

// MARK: - Notes widget: the logo on the Lock Screen, the latest notes at home

/// Reads the list the app wrote to the App Group; never touches the store.
struct RecentEntry: TimelineEntry {
    let date: Date
    let notes: [RecentStore.Summary]
}

struct RecentProvider: TimelineProvider {
    private var sample: [RecentStore.Summary] {
        [
            RecentStore.Summary(id: UUID(), title: "Groceries", preview: "1/4 done · eggs, milk, rice",
                                updatedAt: .now, isPinned: true),
            RecentStore.Summary(id: UUID(), title: "Walking app", preview: "Voice notes on walks",
                                updatedAt: .now, isPinned: false),
            RecentStore.Summary(id: UUID(), title: "Call the dentist", preview: "Tuesday, after 3",
                                updatedAt: .now, isPinned: false),
        ]
    }

    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: .now, notes: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(RecentEntry(date: .now, notes: context.isPreview ? sample : RecentStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        completion(Timeline(entries: [RecentEntry(date: .now, notes: RecentStore.read())], policy: .never))
    }
}

/// Round, on the Lock Screen: the app's logo, and a tap opens the app.
/// Medium and large, on the Home Screen: the latest notes, each a link to
/// itself, with the pencil at the side. The system's colours on the
/// system's widget background, so it looks like the phone's own widgets.
struct RecentNotesView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentEntry

    private var rowCount: Int { family == .systemLarge ? 7 : 3 }
    private var shown: [RecentStore.Summary] { Array(entry.notes.prefix(rowCount)) }

    var body: some View {
        Group {
            if family == .accessoryCircular {
                circular
            } else {
                list
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            LogoMark()
                .padding(4)
        }
        .widgetAccentable()
    }

    private var list: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                if shown.isEmpty {
                    Text("No notes yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap the pencil to write one.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(shown.enumerated()), id: \.offset) { index, note in
                        if let url = note.url {
                            Link(destination: url) { row(note) }
                        } else {
                            row(note)
                        }
                        if index < shown.count - 1 {
                            Rectangle().fill(.quaternary).frame(height: 1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            Link(destination: PinStore.newNoteURL) { Pencil() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ note: RecentStore.Summary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(note.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct RecentNotesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NotesRecent", provider: RecentProvider()) { entry in
            RecentNotesView(entry: entry)
        }
        .configurationDisplayName("Notes")
        .description("Your latest notes. The round one opens the app.")
        .supportedFamilies([.accessoryCircular, .systemMedium, .systemLarge])
    }
}

// MARK: - New note widget: the pencil

struct NewNoteEntry: TimelineEntry {
    let date: Date
}

struct NewNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewNoteEntry { NewNoteEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (NewNoteEntry) -> Void) {
        completion(NewNoteEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewNoteEntry>) -> Void) {
        completion(Timeline(entries: [NewNoteEntry(date: .now)], policy: .never))
    }
}

/// Round, on the Lock Screen, or small, on the Home Screen: the pencil.
/// One tap opens the app on a fresh note.
struct NewNoteView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "pencil")
                        .font(.system(size: 24, weight: .regular))
                }
                .widgetAccentable()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Pencil()
                    Spacer(minLength: 0)
                    Text("New note")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(PinStore.newNoteURL)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct NewNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NotesNew", provider: NewNoteProvider()) { _ in
            NewNoteView()
        }
        .configurationDisplayName("New note")
        .description("One tap, a fresh note.")
        .supportedFamilies([.accessoryCircular, .systemSmall])
    }
}

// MARK: - Marks

/// The app's compose button, at widget size, in the system's colours.
struct Pencil: View {
    var body: some View {
        Image(systemName: "pencil")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.background)
            .frame(width: 40, height: 40)
            .background(.primary, in: Circle())
    }
}

/// The app icon's three bars, drawn from the same numbers as
/// scripts/make-icon.py: a tile inset 23% at the sides, bars placed as
/// fractions of the tile and of the content width. Fills with the primary
/// colour, which the Lock Screen renders white.
struct LogoMark: View {
    private static let inset = 0.23
    private static let bars: [(y: Double, width: Double, height: Double, radius: Double)] = [
        (0.33, 0.62, 0.070, 0.035),
        (0.49, 1.00, 0.044, 0.022),
        (0.62, 0.80, 0.044, 0.022),
    ]

    var body: some View {
        GeometryReader { geometry in
            let tile = min(geometry.size.width, geometry.size.height)
            let content = (1 - 2 * Self.inset) * tile
            let originX = (geometry.size.width - tile) / 2 + Self.inset * tile
            let originY = (geometry.size.height - tile) / 2
            ZStack(alignment: .topLeading) {
                ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, bar in
                    RoundedRectangle(cornerRadius: bar.radius * content, style: .continuous)
                        .fill(.primary)
                        .frame(width: bar.width * content, height: bar.height * tile)
                        .offset(x: originX, y: originY + bar.y * tile)
                }
            }
        }
    }
}

// MARK: - Bundle

@main
struct NotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentNotesWidget()
        NewNoteWidget()
        NotesWidget()
        PinnedNoteLiveActivity()
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NotesWidget()
} timeline: {
    PinnedEntry(date: .now, pinned: PinStore.Pinned(
        id: UUID(), title: "Groceries", preview: "1/4 · eggs, milk, rice", updatedAt: .now))
    PinnedEntry(date: .now, pinned: nil)
}
