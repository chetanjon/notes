import AppIntents
import Foundation

/// "+N more" on the Lock Screen card: expand, then turn the page.
///
/// Like `ToggleChecklistItemIntent`, a `LiveActivityIntent` that runs in
/// the app, which installs `handler` at launch; the extension only builds
/// it for the button. Neither intent touches the store: they change the
/// running activity's content only.
struct ShowMoreItemsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Show more of the pinned note"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Note")
    var noteID: String

    init() {}

    init(noteID: UUID) {
        self.noteID = noteID.uuidString
    }

    static var handler: (@MainActor (UUID) async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: noteID) { await Self.handler?(id) }
        return .result()
    }
}

/// The title tapped while paged: back to the top, three rows.
struct CollapseItemsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Collapse the pinned note"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Note")
    var noteID: String

    init() {}

    init(noteID: UUID) {
        self.noteID = noteID.uuidString
    }

    static var handler: (@MainActor (UUID) async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: noteID) { await Self.handler?(id) }
        return .result()
    }
}
