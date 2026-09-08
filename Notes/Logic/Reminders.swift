import EventKit
import Foundation

/// "Reminders": the dates and times in a note, found by Apple's on-device
/// model, become reminders in the iPhone's Reminders app once the user
/// says so. The one permission the app asks for, and only at that tap.
/// App only.
enum Reminders {
    struct Found: Equatable, Identifiable {
        var title: String
        var due: Date

        var id: String { "\(title)|\(due.timeIntervalSince1970)" }
    }

    /// Writes the reminders into the default list, each with an alarm at
    /// its time. False when access was refused or the save failed.
    static func add(_ found: [Found]) async -> Bool {
        let store = EKEventStore()
        guard let granted = try? await store.requestFullAccessToReminders(), granted else { return false }
        let calendar = Calendar.current
        for item in found {
            let reminder = EKReminder(eventStore: store)
            reminder.title = item.title
            reminder.calendar = store.defaultCalendarForNewReminders()
            reminder.dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.due)
            reminder.addAlarm(EKAlarm(absoluteDate: item.due))
            do { try store.save(reminder, commit: false) } catch { return false }
        }
        do { try store.commit() } catch { return false }
        return true
    }
}
