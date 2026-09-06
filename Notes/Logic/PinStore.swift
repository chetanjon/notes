import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The one pinned note, as the widget sees it.
///
/// The app writes a small record to the App Group's `UserDefaults` whenever
/// a note is pinned, unpinned, or edited while pinned, then asks WidgetKit
/// to reload. The widget only ever reads it. This file is compiled into
/// both targets, so it must not mention the SwiftData model.
enum PinStore {
    static let appGroup = "group.com.cj.notes"
    static let key = "pinned"
    static let urlScheme = "notes"

    struct Pinned: Codable, Equatable {
        let id: UUID
        let title: String
        /// One line, for the inline widget and the Dynamic Island.
        let preview: String
        let updatedAt: Date
        /// Up to four lines to stack under the title: a checklist's open
        /// items, or a plain note's body lines.
        var lines: [String] = []
        /// How many further lines there were.
        var more: Int = 0
        var isChecklist: Bool = false
        var done: Int = 0
        var total: Int = 0

        init(id: UUID, title: String, preview: String, updatedAt: Date,
             lines: [String] = [], more: Int = 0, isChecklist: Bool = false, done: Int = 0, total: Int = 0) {
            self.id = id
            self.title = title
            self.preview = preview
            self.updatedAt = updatedAt
            self.lines = lines
            self.more = more
            self.isChecklist = isChecklist
            self.done = done
            self.total = total
        }

        /// `notes://note/<uuid>`, the URL the widget opens.
        var url: URL? { URL(string: "\(PinStore.urlScheme)://note/\(id.uuidString)") }
    }

    /// Falls back to standard defaults when the App Group is missing, which
    /// is what happens when the entitlement is left off a free-account build.
    /// The app keeps working; only the widget goes blank.
    static var suite: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func write(_ pinned: Pinned?) {
        if let pinned, let data = try? JSONEncoder().encode(pinned) {
            suite.set(data, forKey: key)
        } else {
            suite.removeObject(forKey: key)
        }
        reloadWidgets()
    }

    static func read() -> Pinned? {
        suite.data(forKey: key).flatMap { try? JSONDecoder().decode(Pinned.self, from: $0) }
    }

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// The note id inside a `notes://note/<uuid>` URL, if that is what it is.
    static func noteID(from url: URL) -> UUID? {
        guard url.scheme == urlScheme, url.host == "note" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
