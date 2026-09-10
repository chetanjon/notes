import ActivityKit
import Foundation

/// What the Lock Screen shows for the pinned note, as a Live Activity.
///
/// Compiled into both the app (which starts the activity) and the widget
/// extension (which draws it), so it must stay free of the SwiftData model.
struct PinnedNoteAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        /// A plain note's first body line; shown under the title.
        var preview: String
        /// Counter lines, each with a + on the card.
        var counters: [PinnedCounter]
        var isChecklist: Bool
        var done: Int
        var total: Int
        var updatedAt: Date

        init(_ pinned: PinStore.Pinned) {
            title = pinned.title
            preview = pinned.preview
            counters = pinned.counters
            isChecklist = pinned.isChecklist
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
            counters = try c.decodeIfPresent([PinnedCounter].self, forKey: .counters) ?? []
            isChecklist = try c.decodeIfPresent(Bool.self, forKey: .isChecklist) ?? false
            done = try c.decodeIfPresent(Int.self, forKey: .done) ?? 0
            total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
            updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        }
    }

    /// The note this activity stands for; tapping the activity opens it.
    var noteID: UUID

    init(noteID: UUID) {
        self.noteID = noteID
    }

    /// iOS keeps a running activity's attributes across an app update, so
    /// this has to decode what an older build wrote. Undecodable attributes
    /// hide the running activity from `Activity.activities`, and the app
    /// would then start a second card beside the one already on screen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        noteID = try c.decode(UUID.self, forKey: .noteID)
    }

    /// `notes://note/<uuid>`, the same URL the widget uses.
    var url: URL? { URL(string: "\(PinStore.urlScheme)://note/\(noteID.uuidString)") }
}
