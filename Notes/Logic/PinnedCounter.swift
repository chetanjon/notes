import Foundation

/// A counter line of the pinned note, as the Lock Screen draws it: "Water 3"
/// with a + that edits the note. `line` is the line's index in the note,
/// what the intent needs to find it again. Shared by the app and the
/// widget, so Foundation only.
struct PinnedCounter: Codable, Hashable {
    var label: String
    var value: Int
    var line: Int

    init(label: String, value: Int, line: Int) {
        self.label = label
        self.value = value
        self.line = line
    }

    /// Tolerant, like the records that carry it: a counter that could not
    /// be decoded would take the whole card down with it, since it sits
    /// inside the pinned record and the Live Activity's state.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        value = try c.decodeIfPresent(Int.self, forKey: .value) ?? 0
        line = try c.decodeIfPresent(Int.self, forKey: .line) ?? 0
    }
}
