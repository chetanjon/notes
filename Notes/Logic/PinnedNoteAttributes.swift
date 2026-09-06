import ActivityKit
import Foundation

/// What the Lock Screen shows for the pinned note, as a Live Activity.
///
/// Compiled into both the app (which starts the activity) and the widget
/// extension (which draws it), so it must stay free of the SwiftData model.
struct PinnedNoteAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var preview: String
        var updatedAt: Date
    }

    /// The note this activity stands for; tapping the activity opens it.
    var noteID: UUID

    /// `notes://note/<uuid>`, the same URL the widget uses.
    var url: URL? { URL(string: "\(PinStore.urlScheme)://note/\(noteID.uuidString)") }
}
