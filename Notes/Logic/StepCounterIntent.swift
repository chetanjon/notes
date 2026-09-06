import AppIntents
import Foundation

/// A tap on a counter row on the Lock Screen: "Water 3" becomes "Water 4".
///
/// Same shape as `ToggleChecklistItemIntent`: a `LiveActivityIntent` runs in
/// the app, which installs `handler` at launch. The extension only builds it.
struct StepCounterIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Count one more"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Note")
    var noteID: String

    @Parameter(title: "Line")
    var line: Int

    @Parameter(title: "Delta")
    var delta: Int

    init() {}

    init(noteID: UUID, line: Int, delta: Int = 1) {
        self.noteID = noteID.uuidString
        self.line = line
        self.delta = delta
    }

    /// Installed by the app at launch. Nil in the extension, where it never runs.
    static var handler: (@MainActor (UUID, Int, Int) async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: noteID) {
            await Self.handler?(id, line, delta)
        }
        return .result()
    }
}
