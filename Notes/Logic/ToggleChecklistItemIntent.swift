import AppIntents
import Foundation

/// A tap on a checklist item on the Lock Screen.
///
/// A `LiveActivityIntent` runs in the app's own process (iOS launches the
/// app in the background if it has to), which is why the widget extension
/// can compile this file without knowing anything about the store: the
/// extension only ever constructs the intent for a button. The app installs
/// `handler` at launch, and that is what does the work.
struct ToggleChecklistItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Tick a checklist item"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Note")
    var noteID: String

    @Parameter(title: "Line")
    var line: Int

    init() {}

    init(noteID: UUID, line: Int) {
        self.noteID = noteID.uuidString
        self.line = line
    }

    /// Installed by the app at launch. Nil in the extension, where it never runs.
    static var handler: (@MainActor (UUID, Int) async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: noteID) {
            await Self.handler?(id, line)
        }
        return .result()
    }
}
