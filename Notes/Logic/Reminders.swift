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
        // Only against what the model found, never against each other: two
        // things due at the same time ("gym at 7", "call mum at 7") are two
        // reminders, and comparing the growing list would drop the second.
        let fromModel = result
        for item in spotted where !fromModel.contains(where: { abs($0.due.timeIntervalSince(item.due)) < 60 }) {
            result.append(item)
        }
        return result.sorted { $0.due < $1.due }
    }

    /// What came of writing the reminders, so the sheet can say the right
    /// thing: no permission and no list to write to are different troubles
    /// and need different words.
    enum Outcome: Equatable {
        case added
        case denied
        case noList
        case failed
    }

    /// Writes the reminders into the default list, each with an alarm at
    /// its time.
    static func add(_ found: [Found]) async -> Outcome {
        let store = EKEventStore()
        guard let granted = try? await store.requestFullAccessToReminders(), granted else { return .denied }
        // A phone that has never opened Reminders, or uses only shared
        // lists, has no default list; saving into nil throws, which used to
        // read to the user as "access is off" when it is not.
        guard let list = store.defaultCalendarForNewReminders() else { return .noList }
        let calendar = Calendar.current
        for item in found {
            let reminder = EKReminder(eventStore: store)
            reminder.title = item.title
            reminder.calendar = list
            reminder.dueDateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.due)
            reminder.addAlarm(EKAlarm(absoluteDate: item.due))
            do { try store.save(reminder, commit: false) } catch {
                store.reset()
                return .failed
            }
        }
        do { try store.commit() } catch { return .failed }
        return .added
    }
}
