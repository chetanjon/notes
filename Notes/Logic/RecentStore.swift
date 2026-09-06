import Foundation

/// The notes the Home Screen widget lists: the pinned one first, then the
/// most recently edited, a handful at most. The app writes it to the App
/// Group whenever a note is saved; the widget only reads it. Compiled into
/// both targets, so no SwiftData here.
enum RecentStore {
    static let key = "recent"
    /// How many the widget can ever show; the large size lists seven.
    static let limit = 8

    struct Summary: Codable, Equatable {
        let id: UUID
        let title: String
        let preview: String
        let updatedAt: Date
        let isPinned: Bool

        /// `notes://note/<uuid>`, what a tap on the row opens.
        var url: URL? { URL(string: "\(PinStore.urlScheme)://note/\(id.uuidString)") }
    }

    /// Pinned first, then newest edit first, cut to `limit`.
    static func order(_ notes: [Summary]) -> [Summary] {
        let sorted = notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
        return Array(sorted.prefix(limit))
    }

    static func write(_ notes: [Summary]) {
        if let data = try? JSONEncoder().encode(notes) {
            PinStore.suite.set(data, forKey: key)
        } else {
            PinStore.suite.removeObject(forKey: key)
        }
        PinStore.reloadWidgets()
    }

    static func read() -> [Summary] {
        PinStore.suite.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([Summary].self, from: $0) } ?? []
    }
}
