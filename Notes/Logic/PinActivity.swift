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
    static func show(_ pinned: PinStore.Pinned?) {
        Task { @MainActor in await sync(pinned) }
    }

    @MainActor
    static func sync(_ pinned: PinStore.Pinned?) async {
        let running = Activity<PinnedNoteAttributes>.activities
        guard let pinned else {
            await end(running)
            return
        }
        let state = PinnedNoteAttributes.ContentState(pinned)
        let content = ActivityContent(state: state, staleDate: nil)

        if let current = running.first(where: {
            $0.attributes.noteID == pinned.id && $0.activityState == .active
        }) {
            if current.content.state != state { await current.update(content) }
            await end(running.filter { $0.id != current.id })
            return
        }

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
