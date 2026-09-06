import Foundation
import SwiftData

/// The last deleted note, kept for a few seconds so a swipe can be taken back.
/// One per app, handed to views through the environment.
@Observable
final class Undo {
    struct Deleted {
        let text: String
        let createdAt: Date
        let wasPinned: Bool
    }

    /// How long the bar stays.
    static let window: Duration = .seconds(5)

    private(set) var deleted: Deleted?
    private var expiry: Task<Void, Never>?

    /// Remember `note` just before it is deleted.
    func keep(_ note: Note) {
        deleted = Deleted(text: note.text, createdAt: note.createdAt, wasPinned: note.isPinned)
        expiry?.cancel()
        expiry = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Undo.window)
            guard !Task.isCancelled else { return }
            self?.deleted = nil
        }
    }

    /// Put the note back, with its original creation date and its pin.
    func restore(in context: ModelContext) {
        guard let kept = deleted else { return }
        expiry?.cancel()
        deleted = nil
        let note = Note(text: kept.text)
        note.createdAt = kept.createdAt
        context.insert(note)
        try? context.save()
        if kept.wasPinned { NoteStore.togglePin(note, in: context) }
    }
}
