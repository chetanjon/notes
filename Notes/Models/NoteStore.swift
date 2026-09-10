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
    /// True when neither store on disk would open and the app is running on
    /// a container that lives only until it quits. The list says so, because
    /// anything written in that state is lost.
    private(set) static var isEphemeral = false

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Note.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            return container
        }
        // The same file, without iCloud: a free-account build has no
        // entitlement to carry, and the notes already written are there.
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            return container
        }
        // Neither opened. Crashing here would be a launch loop with no way
        // out but deleting the app, which would take the notes with it, so
        // the app opens on a container that lives in memory and says so.
        if let container = try? ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) {
            isEphemeral = true
            return container
        }
        fatalError("Could not open the notes store, on disk or in memory")
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
        LockScreenSummary.forget(note.text)
        note.isPinned = false
        note.deletedAt = .now
        save(context)
        NoteIndex.remove([note.id])
        Notify.cancel(noteIDs: [note.id])
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
        LockScreenSummary.forget(note.text)
        context.delete(note)
        save(context)
        NoteIndex.remove([id])
        Notify.cancel(noteIDs: [id])
        if wasPinned { showOnLockScreen(nil) }
    }

    static func emptyTrash(in context: ModelContext) {
        let notes = trashed(in: context)
        let ids = notes.map(\.id)
        for note in notes { context.delete(note) }
        save(context)
        NoteIndex.remove(ids)
        Notify.cancel(noteIDs: ids)
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
        Notify.cancel(noteIDs: ids)
    }

    private static func trashed(in context: ModelContext) -> [Note] {
        (try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []
    }

    /// Records an edit. Called by the editor's autosave, which passes
    /// `settled: false`: a notification is only reconciled against text the
    /// user has finished with, since a line cut on its way to being pasted
    /// lower down is absent for a moment and its notification would go for
    /// good.
    static func update(_ note: Note, text: String, in context: ModelContext, settled: Bool = true) {
        guard note.text != text else { return }
        note.text = text
        note.updatedAt = .now
        save(context)
        if !note.isTrashed { NoteIndex.index(note) }
        // A notification whose line left the note goes with it.
        if settled { Notify.reconcile(noteID: note.id, text: text) }
        if note.isPinned {
            showOnLockScreen(pinnedRecord(note))
            summarizeOnLockScreen(note)
        }
    }

    /// "Move this there": what was written in `note` goes to the end of
    /// `older`, and `note` goes to the Trash, so the move is undoable
    /// there. `text` is the editor's current text, which may be ahead of
    /// the last save.
    static func move(text: String, from note: Note, into older: Note, in context: ModelContext) {
        update(older, text: NoteText.appending(text, to: older.text), in: context)
        older.openedAt = .now
        trash(note, in: context)
    }

    /// The editor showed the note: it moves to the top of the list.
    /// Returns when it was last opened before this, nil for never.
    @discardableResult
    static func markOpened(_ note: Note, in context: ModelContext) -> Date? {
        let previous = note.openedAt
        note.openedAt = .now
        save(context)
        return previous
    }

    /// Every note that is not in the Trash and not blank, as the model reads
    /// them, leaving out `excluded`: the older notes a new one is checked
    /// against.
    static func liveCards(in context: ModelContext, excluding excluded: UUID) -> [NoteFinder.Card] {
        let notes = (try? context.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        return notes
            .filter { $0.id != excluded && !$0.isBlank }
            .sorted { $0.touchedAt > $1.touchedAt }
            .map { NoteFinder.Card(id: $0.id, text: $0.text) }
    }

    /// Only one note is pinned at a time; pinning a new one unpins the old.
    static func togglePin(_ note: Note, in context: ModelContext) {
        let wasPinned = note.isPinned
        let all = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        for other in all where other.isPinned { other.isPinned = false }
        note.isPinned = !wasPinned
        save(context)
        showOnLockScreen(note.isPinned ? pinnedRecord(note) : nil)
        if note.isPinned { summarizeOnLockScreen(note) }
    }

    /// On every return to the foreground. Another device may have pinned a
    /// different note, and iOS ends a Live Activity after eight hours, so
    /// both the widget record and the activity are brought back in line
    /// with the store.
    static func syncLockScreen(in context: ModelContext) {
        // Also the repair point for the pin. Two devices can each pin a
        // note before they sync, and a note trashed on one can arrive still
        // flagged from the other, so the flag is trusted only after it has
        // been checked against the Trash and reduced to one.
        let flagged = ((try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.isPinned }))) ?? [])
            .sorted { $0.updatedAt > $1.updatedAt }
        let live = flagged.filter { !$0.isTrashed }
        let keep = live.first
        var repaired = false
        for note in flagged where note.id != keep?.id {
            note.isPinned = false
            repaired = true
        }
        if repaired { save(context) }
        showOnLockScreen(keep.map(pinnedRecord))
        if let keep { summarizeOnLockScreen(keep) }
    }

    /// The note as the Lock Screen shows it, with the model's one-line
    /// summary in place of the first line when it has written one for this
    /// text. The record is rebuilt from the note on every foreground and
    /// every save, so the summary has to be put back each time or it is
    /// lost to the next rebuild.
    private static func pinnedRecord(_ note: Note) -> PinStore.Pinned {
        let record = note.pinned
        guard NoteText.wantsSummary(note.text),
              let line = LockScreenSummary.cached(for: note.text) else { return record }
        return PinStore.Pinned(
            id: record.id, title: record.title, preview: line, updatedAt: record.updatedAt,
            counters: record.counters, isChecklist: record.isChecklist,
            done: record.done, total: record.total)
    }

    /// The pinned note's text has to hold still this long before the model
    /// is asked for its summary.
    private static let summaryDelay: Duration = .seconds(2)

    /// The one summary in flight. A save both writes the record and moves
    /// the list, and the list's own foreground sync asks again, so without
    /// this one edit would ask the model twice for the same text.
    @MainActor private static var summaryTask: Task<Void, Never>?

    /// A long plain note gets a one-line summary under its title on the
    /// card, from the on-device model, once it has answered; the first line
    /// stands in until then, and for good where there is no model. The
    /// answer is used only if the note is still there, still pinned and
    /// unchanged: the note is looked up again after each wait rather than
    /// held, since it can be deleted while the model is thinking.
    private static func summarizeOnLockScreen(_ note: Note) {
        guard LockScreenSummary.isAvailable, NoteText.wantsSummary(note.text) else { return }
        let id = note.id
        let text = note.text
        Task { @MainActor in
            summaryTask?.cancel()
            summaryTask = Task { @MainActor in
                // Typing in the pinned note saves every third of a second;
                // the model is asked only once the text has held still for
                // two.
                try? await Task.sleep(for: summaryDelay)
                guard !Task.isCancelled, stillPinned(id: id, text: text) else { return }
                guard let line = await LockScreenSummary.line(for: text), !Task.isCancelled,
                      stillPinned(id: id, text: text),
                      let current = PinStore.read(), current.id == id, current.preview != line else { return }
                showOnLockScreen(PinStore.Pinned(
                    id: current.id, title: current.title, preview: line, updatedAt: current.updatedAt,
                    counters: current.counters, isChecklist: current.isChecklist,
                    done: current.done, total: current.total))
            }
        }
    }

    /// The note is still in the store, still pinned, and still says what it
    /// said when the model was asked.
    @MainActor
    private static func stillPinned(id: UUID, text: String) -> Bool {
        guard let note = note(withID: id, in: container.mainContext) else { return false }
        return note.isPinned && !note.isTrashed && note.text == text
    }

    /// The Home Screen widget's list: the pinned note, then the rest in the
    /// list's own order (last opened or edited), blank notes left out.
    /// Written after every save and on each foreground, when iCloud may
    /// have changed things.
    /// The widget's list is rebuilt this long after the last save, not on
    /// each one: typing saves three times a second, and each rebuild reads
    /// every note in the store.
    private static let recentDelay: Duration = .milliseconds(800)
    @MainActor private static var recentTask: Task<Void, Never>?

    static func syncRecent(in context: ModelContext) {
        Task { @MainActor in
            recentTask?.cancel()
            recentTask = Task { @MainActor in
                try? await Task.sleep(for: recentDelay)
                guard !Task.isCancelled else { return }
                // The container's own context, not the caller's: a context
                // cannot be carried across to another task, and every caller
                // is on this one anyway.
                writeRecent(in: container.mainContext)
            }
        }
    }

    /// Now, without waiting: the app is going away and the widget should
    /// not be left a save behind.
    static func syncRecentNow(in context: ModelContext) {
        writeRecent(in: context)
    }

    private static func writeRecent(in context: ModelContext) {
        guard let notes = try? context.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.deletedAt == nil })) else {
            // A failed fetch is not an empty store: writing [] here would
            // blank the widget for a reason that has nothing to do with it.
            return
        }
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
    static func stepCounter(noteID: UUID, line: Int, delta: Int, label: String = "") {
        let context = container.mainContext
        guard let note = note(withID: noteID, in: context), !note.isTrashed else { return }
        // The widget's card can be a moment behind the note, so the line the
        // button names is checked against the label it showed: a line added
        // above must not turn a tap on "Water" into a tap on "Pushups".
        let match = NoteText.counters(note.text).first {
            $0.lineIndex == line && (label.isEmpty || $0.label == label)
        }
        // No label to check against (an older widget): the line is trusted.
        guard let target = match?.lineIndex ?? (label.isEmpty ? line : nil),
              let text = NoteText.stepping(counterAt: target, by: delta, in: note.text) else { return }
        update(note, text: text, in: context)
    }

    static func note(withID id: UUID, in context: ModelContext) -> Note? {
        try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })).first
    }

    /// False when the write did not land. Views carry on, since there is
    /// nothing useful to say mid-typing and the next save will try again,
    /// but Siri must not answer "Added milk to Groceries" for a note that
    /// was never written.
    @discardableResult
    private static func save(_ context: ModelContext) -> Bool {
        var saved = true
        do { try context.save() } catch {
            assertionFailure("Save failed: \(error)")
            saved = false
        }
        syncRecent(in: context)
        return saved
    }

    /// The same, for the callers that have to know: the App Intents.
    @discardableResult
    static func saveChecked(_ context: ModelContext) -> Bool {
        save(context)
    }
}
