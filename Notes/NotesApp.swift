import CoreSpotlight
import SwiftData
import SwiftUI
import UserNotifications

@main
struct NotesApp: App {
    @State private var navigation = Navigation()

    init() {
        // A tap on a counter on the Lock Screen card. The intent runs in
        // this process, so this is where it learns how to reach the store.
        StepCounterIntent.handler = { noteID, line, delta in
            NoteStore.stepCounter(noteID: noteID, line: line, delta: delta)
        }
        // A tapped notification opens its note; one that lands while the
        // app is open shows as a banner.
        let navigation = self.navigation
        NotificationRouter.shared.open = { id in navigation.open(id) }
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environment(navigation)
                .preferredColorScheme(.dark)
                .tint(Theme.fg)
                .onOpenURL { url in
                    // notes://note/<uuid> from a widget or the Lock Screen
                    // card; notes://new from the Home Screen widget's pencil.
                    if PinStore.isNewNote(url) {
                        let note = NoteStore.create(in: NoteStore.container.mainContext)
                        navigation.open(note.id)
                    } else if let id = PinStore.noteID(from: url) {
                        navigation.open(id)
                    }
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
