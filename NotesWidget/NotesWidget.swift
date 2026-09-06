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
                .activityBackgroundTint(Theme.bg)
                .activitySystemActionForegroundColor(Theme.fg)
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
                    PinnedStackView(
                        title: context.state.title, lines: context.state.lines,
                        more: context.state.more, isChecklist: context.state.isChecklist,
                        done: context.state.done, total: context.state.total,
                        maxLines: 2, showsPin: false,
                        tappable: TappableItems(noteID: context.attributes.noteID,
                                                lineNumbers: context.state.lineNumbers))
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

/// The card under the clock. Black, like the app; the tint is set on the
/// configuration above.
struct LockScreenPinView: View {
    let noteID: UUID
    let state: PinnedNoteAttributes.ContentState

    var body: some View {
        PinnedStackView(
            title: state.title, lines: state.lines, more: state.more,
            isChecklist: state.isChecklist, done: state.done, total: state.total,
            maxLines: 3, showsPin: true,
            tappable: TappableItems(noteID: noteID, lineNumbers: state.lineNumbers))
        .padding(16)
    }
}

/// What a row needs to tick its item when tapped. The intent is a
/// `LiveActivityIntent`, which iOS runs in the app process, where the
/// store is, whichever surface the button is on: the Live Activity or the
/// widget. (If a widget tap turns out not to reach the app on some iOS,
/// the fallback is a shared store the extension can open; see the plan.)
struct TappableItems {
    let noteID: UUID
    let lineNumbers: [Int]
}

/// Title on top, then the note's lines stacked one to a row: a checklist's
/// open items with their boxes and a count at the right, or a plain note's
/// first lines. Shared by the Live Activity and the widgets, which differ
/// in how many lines fit and whether a tap can tick an item.
struct PinnedStackView: View {
    let title: String
    let lines: [String]
    let more: Int
    let isChecklist: Bool
    let done: Int
    let total: Int
    var maxLines: Int
    var showsPin: Bool
    var tappable: TappableItems? = nil

    private var shown: [String] { Array(lines.prefix(maxLines)) }
    private var hidden: Int { more + (lines.count - shown.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isChecklist, total > 0 {
                    Text("\(done)/\(total)")
                        .font(.system(size: 13, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                }
                if showsPin {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.muted)
                }
            }
            if isChecklist, total > 0, lines.isEmpty {
                Text("All done")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { index, line in
                if isChecklist, let tappable, index < tappable.lineNumbers.count {
                    // The whole row is the button, so a thumb on the Lock
                    // Screen has something to hit.
                    Button(intent: ToggleChecklistItemIntent(
                        noteID: tappable.noteID, line: tappable.lineNumbers[index])) {
                        row(line, box: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    row(line, box: false)
                }
            }
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ line: String, box: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if box {
                Image(systemName: "square")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.fg)
            }
            Text(line)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isChecklist ? Theme.fg : Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Widget: the permanent option, for anyone who adds it

/// Reads the record the app wrote to the App Group; never touches the store.
struct PinnedEntry: TimelineEntry {
    let date: Date
    let pinned: PinStore.Pinned?
}

struct PinnedProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinnedEntry {
        PinnedEntry(date: .now, pinned: PinStore.Pinned(
            id: UUID(), title: "Groceries", preview: "1/4 · eggs, milk, rice", updatedAt: .now,
            lines: ["eggs", "milk", "rice"], lineNumbers: [1, 2, 3], more: 0, isChecklist: true, done: 1, total: 4))
    }

    func getSnapshot(in context: Context, completion: @escaping (PinnedEntry) -> Void) {
        completion(PinnedEntry(date: .now, pinned: context.isPreview ? placeholder(in: context).pinned : PinStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinnedEntry>) -> Void) {
        completion(Timeline(entries: [PinnedEntry(date: .now, pinned: PinStore.read())], policy: .never))
    }
}

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
        .containerBackground(Theme.bg, for: .widget)
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
                PinnedStackView(
                    title: pinned.title, lines: pinned.lines, more: pinned.more,
                    isChecklist: pinned.isChecklist, done: pinned.done, total: pinned.total,
                    maxLines: 2, showsPin: false,
                    tappable: TappableItems(noteID: pinned.id, lineNumbers: pinned.lineNumbers))
            } else {
                Text("Nothing pinned")
                    .font(.headline)
                    .opacity(0.6)
                Text("Long-press a note to pin")
                    .font(.caption)
                    .opacity(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pinned = entry.pinned {
                PinnedStackView(
                    title: pinned.title, lines: pinned.lines, more: pinned.more,
                    isChecklist: pinned.isChecklist, done: pinned.done, total: pinned.total,
                    maxLines: 3, showsPin: false,
                    tappable: TappableItems(noteID: pinned.id, lineNumbers: pinned.lineNumbers))
            } else {
                Text("Nothing pinned")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Text("Long-press a note to pin")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
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

// MARK: - Bundle

@main
struct NotesWidgetBundle: WidgetBundle {
    var body: some Widget {
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
