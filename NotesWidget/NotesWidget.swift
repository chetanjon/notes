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
                        title: context.state.title, rows: context.state.visibleRows,
                        more: context.state.remaining, isChecklist: context.state.isChecklist,
                        done: context.state.done, total: context.state.total,
                        maxLines: 2, showsPin: false, noteID: context.attributes.noteID)
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
            title: state.title, rows: state.visibleRows, more: state.remaining,
            isChecklist: state.isChecklist, done: state.done, total: state.total,
            maxLines: state.page.size, showsPin: true, noteID: noteID,
            page: state.page, paging: true)
        .padding(state.page.expanded ? 14 : 16)
    }
}

/// Title on top, then the note's rows one to a line: a checklist's open
/// items with their boxes and a count at the right, counters with a +, or
/// a plain note's first lines. Shared by the Live Activity and the widgets,
/// which differ in how many rows fit.
///
/// With a `noteID`, item and counter rows are buttons. Their intents are
/// `LiveActivityIntent`s, which iOS runs in the app process whichever
/// surface the button is on, so a tap reaches the store from the widget
/// too. (Should a widget tap not reach the app on some iOS, the fallback
/// is a store the extension can open; see the plan.)
struct PinnedStackView: View {
    let title: String
    let rows: [PinnedRow]
    let more: Int
    let isChecklist: Bool
    let done: Int
    let total: Int
    var maxLines: Int
    var showsPin: Bool
    var noteID: UUID? = nil
    /// Where a paging card is; only the Live Activity pages.
    var page: RowPage = RowPage()
    var paging: Bool = false

    private var shown: [PinnedRow] { Array(rows.prefix(maxLines)) }
    private var hidden: Int { more + (rows.count - shown.count) }
    private var dense: Bool { paging && page.expanded }
    private var titleSize: CGFloat { dense ? 15 : 17 }
    private var rowSize: CGFloat { dense ? 13 : 15 }
    private var allDone: Bool {
        isChecklist && total > 0 && !rows.contains { if case .item = $0 { return true } else { return false } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? 2 : 4) {
            if paging, let noteID, !page.isAtTop {
                // While paged, the title takes the card back to the top.
                Button(intent: CollapseItemsIntent(noteID: noteID)) {
                    titleRow
                }
                .buttonStyle(.plain)
            } else {
                titleRow
            }
            if allDone {
                Text("All done")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, row in
                switch row {
                case let .item(text, line):
                    if let noteID {
                        // The whole row is the button, so a thumb on the
                        // Lock Screen has something to hit.
                        Button(intent: ToggleChecklistItemIntent(noteID: noteID, line: line)) {
                            itemRow(text)
                        }
                        .buttonStyle(.plain)
                    } else {
                        itemRow(text)
                    }
                case let .counter(label, value, line):
                    if let noteID {
                        Button(intent: StepCounterIntent(noteID: noteID, line: line)) {
                            counterRow(label, value: value)
                        }
                        .buttonStyle(.plain)
                    } else {
                        counterRow(label, value: value)
                    }
                case let .text(text):
                    textRow(text)
                }
            }
            if paging, let noteID, hidden > 0 || page.index > 0 {
                // "+N more" expands, then turns the page; on the last page
                // it comes back to the top.
                Button(intent: ShowMoreItemsIntent(noteID: noteID)) {
                    Text(hidden > 0 ? "+\(hidden) more" : "Back to top")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isChecklist, total > 0 {
                Text("\(done)/\(total)")
                    .font(.system(size: 13, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
            if paging, !page.isAtTop {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            } else if showsPin {
                Image(systemName: "pin.fill")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.muted)
            }
        }
        .contentShape(Rectangle())
    }

    private func itemRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "square")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.fg)
            Text(text)
                .font(.system(size: rowSize, weight: .regular))
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    /// "Water  3  +": the number in monospaced digits, the plus at the edge.
    private func counterRow(_ label: String, value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: rowSize, weight: .regular))
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(value)")
                .font(.system(size: rowSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.fg)
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .frame(width: 20)
        }
        .contentShape(Rectangle())
    }

    private func textRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: rowSize, weight: .regular))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
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
            rows: [.item(text: "eggs", line: 1), .item(text: "milk", line: 2), .item(text: "rice", line: 3)],
            more: 0, isChecklist: true, done: 1, total: 4))
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
                    title: pinned.title, rows: pinned.rows, more: pinned.more,
                    isChecklist: pinned.isChecklist, done: pinned.done, total: pinned.total,
                    maxLines: 2, showsPin: false, noteID: pinned.id)
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
                    title: pinned.title, rows: pinned.rows, more: pinned.more,
                    isChecklist: pinned.isChecklist, done: pinned.done, total: pinned.total,
                    maxLines: 3, showsPin: false, noteID: pinned.id)
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
