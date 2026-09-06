import SwiftData
import SwiftUI

@main
struct NotesApp: App {
    @State private var navigation = Navigation()
    @State private var undo = Undo()

    init() {
        // A tap on a checklist item on the Lock Screen. The intent runs in
        // this process, so this is where it learns how to reach the store.
        ToggleChecklistItemIntent.handler = { noteID, line in
            NoteStore.toggleItem(noteID: noteID, line: line)
        }
        StepCounterIntent.handler = { noteID, line, delta in
            NoteStore.stepCounter(noteID: noteID, line: line, delta: delta)
        }
        ShowMoreItemsIntent.handler = { noteID in await PinActivity.showMore(noteID: noteID) }
        CollapseItemsIntent.handler = { noteID in await PinActivity.collapse(noteID: noteID) }
    }

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environment(navigation)
                .environment(undo)
                .preferredColorScheme(.dark)
                .tint(Theme.fg)
                .onOpenURL { url in
                    // notes://note/<uuid>, from the widget.
                    guard let id = PinStore.noteID(from: url) else { return }
                    navigation.open(id)
                }
        }
        .modelContainer(NoteStore.container)
    }
}

/// Which note is open. The list owns the navigation path; the app sets it
/// from a deep link; the widget's URL lands here.
@Observable
final class Navigation {
    var path: [UUID] = []

    func open(_ id: UUID) {
        path = [id]
    }
}
