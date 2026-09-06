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
        /// Stacked under the title, in note order: open items, counters,
        /// or a plain note's body lines.
        var rows: [NoteText.Row]
        var more: Int
        var isChecklist: Bool
        var hasCounters: Bool
        var done: Int
        var total: Int
        var updatedAt: Date

        init(_ pinned: PinStore.Pinned) {
            title = pinned.title
            preview = pinned.preview
            rows = pinned.rows
            more = pinned.more
            isChecklist = pinned.isChecklist
            hasCounters = pinned.hasCounters
            done = pinned.done
            total = pinned.total
            updatedAt = pinned.updatedAt
        }

        /// Fields added after the first release decode as empty, so an
        /// activity started by an older build still draws when the new
        /// extension reads it; the app rewrites it on its next foreground.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(String.self, forKey: .title)
            preview = try c.decodeIfPresent(String.self, forKey: .preview) ?? ""
            rows = try c.decodeIfPresent([NoteText.Row].self, forKey: .rows) ?? []
            more = try c.decodeIfPresent(Int.self, forKey: .more) ?? 0
            isChecklist = try c.decodeIfPresent(Bool.self, forKey: .isChecklist) ?? false
            hasCounters = try c.decodeIfPresent(Bool.self, forKey: .hasCounters) ?? false
            done = try c.decodeIfPresent(Int.self, forKey: .done) ?? 0
            total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
            updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        }
    }

    /// The note this activity stands for; tapping the activity opens it.
    var noteID: UUID

    /// `notes://note/<uuid>`, the same URL the widget uses.
    var url: URL? { URL(string: "\(PinStore.urlScheme)://note/\(noteID.uuidString)") }
}
