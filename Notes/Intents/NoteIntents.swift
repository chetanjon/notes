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
        let context = NoteStore.container.mainContext
        let note = NoteStore.create(in: context)
        NoteStore.update(note, text: text, in: context)
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

enum NoteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case gone

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .gone: "That note is gone."
        }
    }
}

/// The phrases Siri answers to without any setup. The app's name in a
/// phrase is "Notes" (the Home Screen name) or "Matte" (the store name),
/// through INAlternativeAppNames in project.yml.
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
    }
}
