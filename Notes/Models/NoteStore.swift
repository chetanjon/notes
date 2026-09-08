import Foundation
import SwiftData

/// The few operations that touch more than one note or reach outside the
/// model context: creating, trashing, deleting, pinning. Views call these
/// instead of editing the context directly so the pin invariant, the Lock
/// Screen, and the phone's search index are kept in one place.
enum NoteStore {
    /// The one container. The app's views read it through the environment;
    /// the Lock Screen intent reaches it through here.
    static let container: ModelContainer = makeContainer()

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

    /// Moves the note to the Trash: out of the list, unpinned, kept for
    /// thirty days. No confirmation, as the spec says; the Trash is the way
    /// back.
    static func trash(_ note: Note, in context: ModelContext) {
        let wasPinned = note.isPinned
        note.isPinned = false
        note.deletedAt = .now
        save(context)
        NoteIndex.remove([note.id])
        if wasPinned { showOnLockScreen(nil) }
    }

    /// Back from the Trash, where it was in the list before.
    static func restore(_ note: Note, in context: ModelContext) {
        note.deletedAt = nil
        save(context)
        NoteIndex.index(note)
    }

    /// Gone for good: the Trash's own delete, a blank note on dismiss, and
    /// what expiry does.
    static func erase(_ note: Note, in context: ModelContext) {
        let wasPinned = note.isPinned
        let id = note.id
        context.delete(note)
        save(context)
        NoteIndex.remove([id])
        if wasPinned { showOnLockScreen(nil) }
    }

    static func emptyTrash(in context: ModelContext) {
        let notes = trashed(in: context)
        let ids = notes.map(\.id)
        for note in notes { context.delete(note) }
        save(context)
        NoteIndex.remove(ids)
    }

    /// Deletes every note that has sat in the Trash past `Trash.retention`.
    /// Run on each return to the foreground.
    static func purgeTrash(in context: ModelContext) {
        let expired = trashed(in: context).filter { note in
            note.deletedAt.map { Trash.isExpired(deletedAt: $0) } ?? false
        }
        guard !expired.isEmpty else { return }
        let ids = expired.map(\.id)
        for note in expired { context.delete(note) }
        save(context)
        NoteIndex.remove(ids)
    }

    private static func trashed(in context: ModelContext) -> [Note] {
        (try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []
    }

    /// Records an edit. Called by the editor's autosave.
    static func update(_ note: Note, text: String, in context: ModelContext) {
        guard note.text != text else { return }
        note.text = text
        note.updatedAt = .now
        save(context)
        if !note.isTrashed { NoteIndex.index(note) }
        if note.isPinned { showOnLockScreen(note.pinned) }
    }

    /// The editor showed the note: it moves to the top of the list.
    static func markOpened(_ note: Note, in context: ModelContext) {
        note.openedAt = .now
        save(context)
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

    /// The Home Screen widget's list: the pinned note, then the rest in the
    /// list's own order (last opened or edited), blank notes left out.
    /// Written after every save and on each foreground, when iCloud may
    /// have changed things.
    static func syncRecent(in context: ModelContext) {
        let notes = (try? context.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        let recent = RecentStore.order(notes.filter { !$0.isBlank }.map {
            RecentStore.Summary(id: $0.id, title: $0.title, preview: $0.preview,
                                updatedAt: $0.touchedAt, isPinned: $0.isPinned)
        })
        if RecentStore.read() != recent { RecentStore.write(recent) }
    }

    /// The Live Activity is what the user sees at once; the App Group record
    /// feeds the widget for anyone who added it.
    private static func showOnLockScreen(_ record: PinStore.Pinned?) {
        if PinStore.read() != record { PinStore.write(record) }
        PinActivity.show(record)
    }

    /// A tap on a counter on the Lock Screen: move the number on that line.
    @MainActor
    static func stepCounter(noteID: UUID, line: Int, delta: Int) {
        let context = container.mainContext
        guard let note = note(withID: noteID, in: context),
              let text = NoteText.stepping(counterAt: line, by: delta, in: note.text) else { return }
        update(note, text: text, in: context)
    }

    static func note(withID id: UUID, in context: ModelContext) -> Note? {
        try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })).first
    }

    private static func save(_ context: ModelContext) {
        do { try context.save() } catch { assertionFailure("Save failed: \(error)") }
        syncRecent(in: context)
    }
}
