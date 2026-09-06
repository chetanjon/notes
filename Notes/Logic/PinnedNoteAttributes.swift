import ActivityKit
import Foundation

/// What the Lock Screen shows for the pinned note, as a Live Activity.
///
/// Compiled into both the app (which starts the activity) and the widget
/// extension (which draws it), so it must stay free of the SwiftData model.
struct PinnedNoteAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        /// One line, for the Dynamic Island's compact form.
        var preview: String
        /// Stacked under the title: a checklist's open items, or body lines.
        var lines: [String]
        /// The note line each entry of `lines` is, for a checklist, so the
        /// tap that ticks it can name it.
        var lineNumbers: [Int]
        var more: Int
        var isChecklist: Bool
        var done: Int
        var total: Int
        var updatedAt: Date

        init(_ pinned: PinStore.Pinned) {
            title = pinned.title
            preview = pinned.preview
            lines = pinned.lines
            lineNumbers = pinned.lineNumbers
            more = pinned.more
            isChecklist = pinned.isChecklist
            done = pinned.done
            total = pinned.total
            updatedAt = pinned.updatedAt
        }
    }

    /// The note this activity stands for; tapping the activity opens it.
    var noteID: UUID

    /// `notes://note/<uuid>`, the same URL the widget uses.
    var url: URL? { URL(string: "\(PinStore.urlScheme)://note/\(noteID.uuidString)") }
}
