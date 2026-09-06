import AppIntents
import Foundation
import SwiftData

/// A note as Siri and Shortcuts see it: its id and its title.
struct NoteEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")
    static var defaultQuery = NoteQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(_ note: Note) {
        id = note.id
        title = note.title
    }
}

/// Finds notes by title, for "Add milk to Groceries": the ones not in the
/// Trash, the pinned one first, then the most recently edited.
struct NoteQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        let context = NoteStore.container.mainContext
        return identifiers.compactMap { id in
            guard let note = NoteStore.note(withID: id, in: context), !note.isTrashed else { return nil }
            return NoteEntity(note)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [NoteEntity] {
        let query = string.trimmingCharacters(in: .whitespaces)
        return live()
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
            .map(NoteEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteEntity] {
        live().prefix(20).map(NoteEntity.init)
    }

    @MainActor
    private func live() -> [Note] {
        let context = NoteStore.container.mainContext
        let notes = (try? context.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        return notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }
}
