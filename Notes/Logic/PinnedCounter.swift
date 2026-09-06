import Foundation

/// A counter line of the pinned note, as the Lock Screen draws it: "Water 3"
/// with a + that edits the note. `line` is the line's index in the note,
/// what the intent needs to find it again. Shared by the app and the
/// widget, so Foundation only.
struct PinnedCounter: Codable, Hashable {
    var label: String
    var value: Int
    var line: Int
}
