import Foundation
import UserNotifications

/// "Notify me": a dated line in a note becomes a one-time notification from
/// the app at its time, with the note's title and the line, and a tap that
/// opens the note. Cancelled when the note goes to the Trash or the line
/// leaves the note. No repeats, no snooze: that is the Reminders app's job.
/// App only.
enum Notify {
    /// What came of asking for notifications, so the sheet can say the
    /// right thing: "off in Settings" and "too many already" are not the
    /// same trouble, and neither is "iOS refused the request".
    enum Outcome: Equatable {
        case set(Int)
        case denied
        case full
    }

    /// Asks once. The count is how many iOS actually took.
    static func schedule(_ found: [Reminders.Found], noteID: UUID, noteTitle: String) async -> Outcome {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return .denied }
        let pending = await center.pendingNotificationRequests().count
        guard pending + found.count <= NotifyPlan.pendingLimit else { return .full }
        let calendar = Calendar.current
        var added = 0
        for item in found where item.due > .now {
            let content = UNMutableNotificationContent()
            content.title = noteTitle
            content.body = item.title
            content.sound = .default
            content.threadIdentifier = noteID.uuidString
            content.userInfo = ["noteID": noteID.uuidString]
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.due)
            let request = UNNotificationRequest(
                identifier: NotifyPlan.identifier(noteID: noteID, body: item.title, due: item.due),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            do {
                try await center.add(request)
                added += 1
            } catch {
                continue
            }
        }
        return added > 0 ? .set(added) : .denied
    }

    /// Pending notifications for notes that are no longer in the store: a
    /// note deleted on another device syncs its deletion in, but nothing
    /// local cancelled its notifications. Run on each foreground.
    static func cancelOrphans(liveNoteIDs: Set<UUID>) {
        let live = Set(liveNoteIDs.map(\.uuidString))
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { !$0.content.threadIdentifier.isEmpty && !live.contains($0.content.threadIdentifier) }
                .map(\.identifier)
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }

    /// Everything pending for these notes: the Trash, or gone for good.
    static func cancel(noteIDs: [UUID]) {
        let threads = Set(noteIDs.map(\.uuidString))
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { threads.contains($0.content.threadIdentifier) }.map(\.identifier)
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }

    /// After an edit has settled: a pending notification whose line is no
    /// longer in the note is cancelled. Only on settled text, never on an
    /// autosave mid-edit: cutting a line to paste it lower down would
    /// otherwise cancel its notification for good.
    static func reconcile(noteID: UUID, text: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let mine = requests.filter { $0.content.threadIdentifier == noteID.uuidString }
            guard !mine.isEmpty else { return }
            let stale = Set(NotifyPlan.stale(mine.map(\.content.body), in: text))
            let ids = mine.filter { stale.contains($0.content.body) }.map(\.identifier)
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }
}

/// Where a tapped notification goes: the note. Also lets one show while
/// the app is open, as a banner. Set as the centre's delegate at launch.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    var open: ((UUID) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["noteID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run { open?(id) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
