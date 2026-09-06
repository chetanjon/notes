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
        var state = PinnedNoteAttributes.ContentState(pinned)

        if let current = running.first(where: {
            $0.attributes.noteID == pinned.id && $0.activityState == .active
        }) {
            // Keep the card where the user left it; only the rows changed.
            state.page = current.content.state.page.clamped(rowCount: state.rows.count)
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

    /// "+N more" on the card.
    @MainActor
    static func showMore(noteID: UUID) async {
        await turn(noteID: noteID) { state in state.page.advanced(rowCount: state.rows.count) }
    }

    /// The title tapped while paged.
    @MainActor
    static func collapse(noteID: UUID) async {
        await turn(noteID: noteID) { state in state.page.collapsed() }
    }

    @MainActor
    private static func turn(noteID: UUID,
                             to page: (PinnedNoteAttributes.ContentState) -> RowPage) async {
        guard let current = Activity<PinnedNoteAttributes>.activities.first(where: {
            $0.attributes.noteID == noteID && $0.activityState == .active
        }) else { return }
        var state = current.content.state
        state.page = page(state)
        guard state != current.content.state else { return }
        await current.update(ActivityContent(state: state, staleDate: nil))
    }

    private static func end(_ activities: [Activity<PinnedNoteAttributes>]) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
