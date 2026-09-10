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

    /// The most counters the card carries; a Live Activity has little height.
    static let maxCounters = 3

    struct Pinned: Codable, Equatable {
        let id: UUID
        let title: String
        /// One line under the title: a plain note's first body line, or a
        /// checklist's "2/5 · milk, eggs" for the inline widget.
        let preview: String
        let updatedAt: Date
        /// Up to `maxCounters` counter lines, each with a + on the card.
        var counters: [PinnedCounter] = []
        var isChecklist: Bool = false
        var done: Int = 0
        var total: Int = 0

        init(id: UUID, title: String, preview: String, updatedAt: Date,
             counters: [PinnedCounter] = [], isChecklist: Bool = false,
             done: Int = 0, total: Int = 0) {
            self.id = id
            self.title = title
            self.preview = preview
            self.updatedAt = updatedAt
            self.counters = counters
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

    /// A reload asked for while one is already queued. Typing in a pinned
    /// note saves three times a second, and each save writes both the
    /// pinned record and the recent list, so without this every keystroke
    /// would re-render all four widget kinds twice.
    private static let reloadDelay: Duration = .milliseconds(400)
    @MainActor private static var reloadTask: Task<Void, Never>?

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        Task { @MainActor in
            reloadTask?.cancel()
            reloadTask = Task { @MainActor in
                try? await Task.sleep(for: reloadDelay)
                guard !Task.isCancelled else { return }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #endif
    }

    /// The note id inside a `notes://note/<uuid>` URL, if that is what it is.
    static func noteID(from url: URL) -> UUID? {
        guard url.scheme == urlScheme, url.host == "note" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    /// `notes://new`: the Home Screen widget's pencil, a fresh note.
    static let newNoteURL = URL(string: "\(urlScheme)://new")!

    static func isNewNote(_ url: URL) -> Bool {
        url.scheme == urlScheme && url.host == "new"
    }
}
