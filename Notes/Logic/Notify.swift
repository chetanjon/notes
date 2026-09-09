import Foundation
import UserNotifications

/// "Notify me": a dated line in a note becomes a one-time notification from
/// the app at its time, with the note's title and the line, and a tap that
/// opens the note. Cancelled when the note goes to the Trash or the line
/// leaves the note. No repeats, no snooze: that is the Reminders app's job.
/// App only.
enum Notify {
    /// Asks once; false when refused, or when the pending limit is reached.
    static func schedule(_ found: [Reminders.Found], noteID: UUID, noteTitle: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        let pending = await center.pendingNotificationRequests().count
        guard pending + found.count <= NotifyPlan.pendingLimit else { return false }
        let calendar = Calendar.current
        for item in found where item.due > .now {
            let content = UNMutableNotificationContent()
            content.title = noteTitle
            content.body = item.title
            content.sound = .default
            content.threadIdentifier = noteID.uuidString
            content.userInfo = ["noteID": noteID.uuidString]
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.due)
            let request = UNNotificationRequest(
                identifier: NotifyPlan.identifier(noteID: noteID, body: item.title),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
        return true
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

    /// After an edit: a pending notification whose line is no longer in the
    /// note is cancelled.
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
