import AppIntents
import Foundation

/// What Siri and Shortcuts can do with notes, with no setup: write one,
/// add to a list, pin one. The intents run in the app, which iOS starts
/// in the background if it has to.

/// "New note in Matte": a note with the text Siri heard; its first line is
/// the title, as always.
struct CreateNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "New Note"
    static var description = IntentDescription("Writes a new note. The first line is its title.")
    static var openAppWhenRun = false

    @Parameter(title: "Text")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("New note \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity> & ProvidesDialog {
        // Siri heard nothing usable: no note rather than a blank one that
        // nothing would ever clear away, since the editor never opens here.
        guard !NoteText.isBlank(text) else { throw NoteIntentError.empty }
        OnDevice.prewarm()
        let context = NoteStore.container.mainContext
        let note = NoteStore.create(in: context)
        // Shaped by the pure rules, which cost nothing: a spoken note gets
        // a title and a checklist here as it does everywhere else, where
        // before it was saved as one run-on line exactly as Siri heard it.
        NoteStore.update(note, text: Dictation.plain(text), in: context)
        // The store can refuse a write, and a locked phone is one of the
        // ways: better to say so than to answer "Added" for nothing.
        guard NoteStore.saveChecked(context) else { throw NoteIntentError.notSaved }
        // Only now the model, and only briefly. Saving first is what makes
        // the short deadline safe: iOS can stop an intent at any moment,
        // and if it does the note is already there and already shaped.
        if OnDevice.isAvailable,
           case let .cleaned(better) = await withTimeout(Dictation.siriLimit, {
               await OnDevice.cleaned(dictation: text)
           }) ?? .tooSlow {
            NoteStore.update(note, text: better, in: context)
            _ = NoteStore.saveChecked(context)
        }
        NotesShortcuts.updateAppShortcutParameters()
        // Read after the model, so Siri says the better title where there
        // is one. Nothing is said about a cleanup that did not happen:
        // there is no room in a spoken answer for a caveat nobody asked for.
        return .result(value: NoteEntity(note), dialog: "Added \(note.title).")
    }
}

/// "Add milk to Groceries in Matte": a new open item at the end of the note.
struct AddToListIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to List"
    static var description = IntentDescription("Adds an item to the end of a note, as a checklist item.")
    static var openAppWhenRun = false

    @Parameter(title: "Item")
    var item: String

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$item) to \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = NoteStore.container.mainContext
        guard let target = NoteStore.note(withID: note.id, in: context), !target.isTrashed else {
            throw NoteIntentError.gone
        }
        NoteStore.update(target, text: Checklist.appendingItem(item, to: target.text), in: context)
        guard NoteStore.saveChecked(context) else { throw NoteIntentError.notSaved }
        return .result(dialog: "Added \(item) to \(target.title).")
    }
}

/// "Pin Groceries in Matte". Opens the app: a Live Activity can only be
/// started from the foreground, and the app puts the card up as it opens.
struct PinNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Pin Note"
    static var description = IntentDescription("Puts a note on the Lock Screen, in place of the one there.")
    static var openAppWhenRun = true

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Pin \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = NoteStore.container.mainContext
        guard let target = NoteStore.note(withID: note.id, in: context), !target.isTrashed else {
            throw NoteIntentError.gone
        }
        if !target.isPinned { NoteStore.togglePin(target, in: context) }
        return .result()
    }
}

/// "What's on Groceries in Matte": Siri reads the open items, or a plain
/// note's first lines. Nothing changes.
struct ReadNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Note"
    static var description = IntentDescription("Reads a note out: what is left on a checklist, or the first lines of a plain note.")
    static var openAppWhenRun = false

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Read \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let context = NoteStore.container.mainContext
        guard let target = NoteStore.note(withID: note.id, in: context), !target.isTrashed else {
            throw NoteIntentError.gone
        }
        let spoken = NoteText.spoken(target.text)
        return .result(value: spoken, dialog: "\(spoken)")
    }
}

/// "Tick milk off Groceries in Matte": the first open item that matches
/// the words is marked done.
struct TickItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Tick Off"
    static var description = IntentDescription("Marks an item on a checklist as done.")
    static var openAppWhenRun = false

    @Parameter(title: "Item")
    var item: String

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Tick \(\.$item) off \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = NoteStore.container.mainContext
        guard let target = NoteStore.note(withID: note.id, in: context), !target.isTrashed else {
            throw NoteIntentError.gone
        }
        guard let ticked = Checklist.ticking(item, in: target.text) else {
            return .result(dialog: "There is no \(item) left on \(target.title).")
        }
        NoteStore.update(target, text: ticked.text, in: context)
        guard NoteStore.saveChecked(context) else { throw NoteIntentError.notSaved }
        let summary = NoteText.checklistSummary(ticked.text)
        let left = summary.open.isEmpty ? "That was the last one." : "\(summary.open.count) left."
        return .result(dialog: "Ticked off \(ticked.item). \(left)")
    }
}

enum NoteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case gone
    case empty
    case notSaved

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .gone: "That note is gone."
        case .empty: "There was nothing to write down."
        case .notSaved: "That could not be saved. Try again with the phone unlocked."
        }
    }
}

/// "Dictate a note in Matte": the app opens already listening.
///
/// This one opens the app, where New Note does not, because the microphone
/// needs the app in front and no third-party app gets it from a locked
/// phone. From the Lock Screen that means one glance at Face ID and then
/// the listening sheet, with no Home Screen and no hunting for the app,
/// which is as close to hands-free as iOS allows. Truly hands-free is
/// "New note in Matte", which writes in the background and works locked.
struct DictateNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Dictate a Note"
    static var description = IntentDescription("Opens Matte and starts listening.")
    static var openAppWhenRun = true

    /// Installed by the app as it starts. The intent can run before there
    /// is anything to tell, which is what a cold launch looks like, so the
    /// request waits in `requested` until the list comes up and takes it.
    @MainActor static var handler: (() -> Void)?
    @MainActor static var requested = false

    @MainActor
    func perform() async throws -> some IntentResult {
        if let handler = Self.handler {
            handler()
        } else {
            Self.requested = true
        }
        return .result()
    }
}

/// The phrases Siri answers to without any setup. The app's name in a
/// phrase is "Matte", the name on the Home Screen and in the store.
struct NotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "New note in \(.applicationName)",
                "Write a note in \(.applicationName)",
            ],
            shortTitle: "New Note",
            systemImageName: "square.and.pencil")
        AppShortcut(
            intent: DictateNoteIntent(),
            phrases: [
                "Dictate a note in \(.applicationName)",
                "Take a voice note in \(.applicationName)",
            ],
            shortTitle: "Dictate a Note",
            systemImageName: "mic")
        AppShortcut(
            intent: AddToListIntent(),
            phrases: [
                "Add to \(\.$note) in \(.applicationName)",
                "Add something to \(\.$note) in \(.applicationName)",
            ],
            shortTitle: "Add to List",
            systemImageName: "checklist")
        AppShortcut(
            intent: PinNoteIntent(),
            phrases: [
                "Pin \(\.$note) in \(.applicationName)",
                "Put \(\.$note) on my Lock Screen in \(.applicationName)",
            ],
            shortTitle: "Pin Note",
            systemImageName: "pin")
        AppShortcut(
            intent: ReadNoteIntent(),
            phrases: [
                "What's on \(\.$note) in \(.applicationName)",
                "What is on \(\.$note) in \(.applicationName)",
                "What's on my \(\.$note) list in \(.applicationName)",
                "Read \(\.$note) in \(.applicationName)",
                "What's left on \(\.$note) in \(.applicationName)",
            ],
            shortTitle: "Read Note",
            systemImageName: "text.bubble")
        AppShortcut(
            intent: TickItemIntent(),
            phrases: [
                "Tick something off \(\.$note) in \(.applicationName)",
                "Tick off \(\.$note) in \(.applicationName)",
                "Check something off \(\.$note) in \(.applicationName)",
            ],
            shortTitle: "Tick Off",
            systemImageName: "checkmark.circle")
    }
}
