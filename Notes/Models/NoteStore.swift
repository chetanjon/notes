import Foundation
import SwiftData

/// The few operations that touch more than one note or reach outside the
/// model context: creating, deleting, pinning. Views call these instead of
/// editing the context directly so the pin invariant and the Lock Screen
/// are kept in one place.
enum NoteStore {
    /// The container the app runs on. CloudKit when the entitlement is
    /// there, local storage when it is not, so a free-account build that
    /// cannot carry the iCloud capability still opens.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Note.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            return container
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("Could not open the notes store: \(error)")
        }
    }

    @discardableResult
    static func create(in context: ModelContext) -> Note {
        let note = Note()
        context.insert(note)
        save(context)
        return note
    }

    static func delete(_ note: Note, in context: ModelContext) {
        let wasPinned = note.isPinned
        context.delete(note)
        save(context)
        if wasPinned { showOnLockScreen(nil) }
    }

    /// Records an edit. Called by the editor's autosave.
    static func update(_ note: Note, text: String, in context: ModelContext) {
        guard note.text != text else { return }
        note.text = text
        note.updatedAt = .now
        save(context)
        if note.isPinned { showOnLockScreen(note.pinned) }
    }

    /// Only one note is pinned at a time; pinning a new one unpins the old.
    static func togglePin(_ note: Note, in context: ModelContext) {
        let wasPinned = note.isPinned
        let all = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        for other in all where other.isPinned { other.isPinned = false }
        note.isPinned = !wasPinned
        save(context)
        showOnLockScreen(note.isPinned ? note.pinned : nil)
    }

    /// On every return to the foreground. Another device may have pinned a
    /// different note, and iOS ends a Live Activity after eight hours, so
    /// both the widget record and the activity are brought back in line
    /// with the store.
    static func syncLockScreen(in context: ModelContext) {
        let pinned = try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.isPinned })).first
        showOnLockScreen(pinned?.pinned)
    }

    /// The Live Activity is what the user sees at once; the App Group record
    /// feeds the widget for anyone who added it.
    private static func showOnLockScreen(_ record: PinStore.Pinned?) {
        if PinStore.read() != record { PinStore.write(record) }
        PinActivity.show(record)
    }

    static func note(withID id: UUID, in context: ModelContext) -> Note? {
        try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })).first
    }

    private static func save(_ context: ModelContext) {
        do { try context.save() } catch { assertionFailure("Save failed: \(error)") }
    }
}
