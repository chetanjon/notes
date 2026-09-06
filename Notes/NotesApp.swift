import CoreSpotlight
import SwiftData
import SwiftUI

@main
struct NotesApp: App {
    @State private var navigation = Navigation()

    init() {
        // A tap on a counter on the Lock Screen card. The intent runs in
        // this process, so this is where it learns how to reach the store.
        StepCounterIntent.handler = { noteID, line, delta in
            NoteStore.stepCounter(noteID: noteID, line: line, delta: delta)
        }
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
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    // A note tapped in the iPhone's search.
                    guard let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                          let id = UUID(uuidString: raw) else { return }
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
