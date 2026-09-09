import EventKit
import Foundation

/// "Reminders": the dates and times in a note, found on the phone, become
/// reminders in the iPhone's Reminders app once the user says so. The
/// permission is asked for at that tap and never before. App only.
enum Reminders {
    struct Found: Equatable, Identifiable {
        var title: String
        var due: Date

        var id: String { "\(title)|\(due.timeIntervalSince1970)" }
    }

    /// Everything in the note with a day or a time: what `DateSpotter`
    /// reads off the lines, and, on an iPhone with the model, what the
    /// model found as well, its titles winning where both found the same
    /// moment. Soonest first. The spotter runs whatever the model does, so
    /// an odd line never costs the plain ones.
    static func find(in text: String, now: Date = .now) async -> [Found] {
        let spotted = DateSpotter.find(in: text, now: now).map { Found(title: $0.title, due: $0.due) }
        var result = await OnDevice.reminders(in: text, now: now) ?? []
        for item in spotted where !result.contains(where: { abs($0.due.timeIntervalSince(item.due)) < 60 }) {
            result.append(item)
        }
        return result.sorted { $0.due < $1.due }
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
