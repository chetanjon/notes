import ActivityKit
import Foundation

/// Puts the pinned note on the Lock Screen the moment it is pinned, with no
/// setup by the user, as a Live Activity.
///
/// iOS ends every Live Activity on its own after eight hours, and a user can
/// swipe one away. So this is called again whenever the app comes to the
/// foreground: if a note is pinned and nothing is showing, it is shown again.
/// The widget remains the permanent alternative for anyone who adds it.
///
/// App only. Extensions cannot start activities, and `PinStore` (which both
/// targets share) must not import this.
enum PinActivity {
    /// Show `pinned` on the Lock Screen, or clear it when nil. Safe to call
    /// often: an activity already showing the same content is left alone.
    ///
    /// Calls run one after another. Coming to the foreground, the app asks
    /// twice within a moment (once for the scene, once as the notes load);
    /// run side by side, both would find nothing showing and both would
    /// start an activity, and the note would be on the Lock Screen twice.
    static func show(_ pinned: PinStore.Pinned?) {
        Task { @MainActor in
            // Typing in the pinned note saves three times a second, and iOS
            // budgets how often an activity may be updated: past it the card
            // is throttled or ended. So the last state within the window is
            // the one that goes, unless the card is being taken down, which
            // should not wait.
            pending?.cancel()
            guard pinned != nil else {
                await run(nil)
                return
            }
            pending = Task { @MainActor in
                try? await Task.sleep(for: updateDelay)
                guard !Task.isCancelled else { return }
                await run(pinned)
            }
        }
    }

    /// How long the pinned note's text has to hold still before the card is
    /// told about it.
    private static let updateDelay: Duration = .milliseconds(500)
    @MainActor private static var pending: Task<Void, Never>?

    /// One at a time, in order.
    @MainActor
    private static func run(_ pinned: PinStore.Pinned?) async {
        let previous = latest
        let task = Task { @MainActor in
            await previous?.value
            await sync(pinned)
        }
        latest = task
        await task.value
    }

    /// The last call's task; the next waits on it.
    @MainActor private static var latest: Task<Void, Never>?

    @MainActor
    static func sync(_ pinned: PinStore.Pinned?) async {
        let running = Activity<PinnedNoteAttributes>.activities
        guard let pinned else {
            await end(running)
            return
        }
        let state = PinnedNoteAttributes.ContentState(pinned)

        if let current = running.first(where: {
            $0.attributes.noteID == pinned.id && $0.activityState == .active
        }) {
            if current.content.state != state {
                await current.update(ActivityContent(state: state, staleDate: nil))
            }
            await end(running.filter { $0.id != current.id })
            return
        }

        let content = ActivityContent(state: state, staleDate: nil)
        await end(running)
        // Off in Settings, or the system is at its limit: the widget still
        // carries the note, so there is nothing to tell the user here.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity<PinnedNoteAttributes>.request(
                attributes: PinnedNoteAttributes(noteID: pinned.id),
                content: content,
                pushType: nil)
        } catch {
            // Same as above: a refused request degrades to the widget.
        }
    }

    private static func end(_ activities: [Activity<PinnedNoteAttributes>]) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
