import Foundation

/// One row on the Lock Screen. Codable and Hashable so it can sit in the
/// pinned record and the Live Activity's state as it is. Its own file,
/// Foundation only, because the widget extension compiles it and not the
/// text logic that produces it.
enum PinnedRow: Codable, Hashable {
    /// An open checklist item, and the note line it is on.
    case item(text: String, line: Int)
    /// A line like "Water 3": a label, a number, and the note line.
    case counter(label: String, value: Int, line: Int)
    /// A plain note's body line.
    case text(String)

    var line: Int? {
        switch self {
        case let .item(_, line), let .counter(_, _, line): return line
        case .text: return nil
        }
    }
}
