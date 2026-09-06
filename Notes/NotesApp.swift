import SwiftData
import SwiftUI

@main
struct NotesApp: App {
    @State private var navigation = Navigation()

    init() {
        // Taps on the Lock Screen card. The intents run in this process, so
        // this is where they learn how to reach the store and the activity.
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

/// Where the list has gone: into a note, or into the Trash. The list owns
/// the navigation path; the app sets it from a deep link; the widget's URL
/// lands here.
@Observable
final class Navigation {
    enum Route: Hashable {
        case note(UUID)
        case trash
    }

    var path: [Route] = []

    func open(_ id: UUID) {
        path = [.note(id)]
    }
}
