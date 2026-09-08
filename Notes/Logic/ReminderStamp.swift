import Foundation

/// The date the on-device model writes for a reminder, and the day it is
/// told it is. Pure, so the parsing is tested without the model.
enum ReminderStamp {
    /// The hour a date with no time is due.
    static let morning = 9

    /// `2026-09-15T15:00` (24-hour) or `2026-09-15` (nine in the morning) in
    /// the given calendar; nil for anything else.
    static func parse(_ stamp: String, calendar: Calendar = .current) -> Date? {
        let parts = stamp.trimmingCharacters(in: .whitespaces)
            .split(separator: "T", maxSplits: 1).map(String.init)
        guard let day = parts.first else { return nil }
        let d = day.split(separator: "-").map(String.init).compactMap { Int($0) }
        guard d.count == 3, (1...12).contains(d[1]), (1...31).contains(d[2]) else { return nil }
        var components = DateComponents(year: d[0], month: d[1], day: d[2], hour: morning, minute: 0)
        if parts.count == 2 {
            let t = parts[1].split(separator: ":").map(String.init).compactMap { Int($0) }
            guard t.count >= 2, (0...23).contains(t[0]), (0...59).contains(t[1]) else { return nil }
            components.hour = t[0]
            components.minute = t[1]
        }
        return calendar.date(from: components)
    }

    /// What the model is told about now, so "tuesday" and "tomorrow" land
    /// on a date: `Tuesday, 2026-09-08`.
    static func today(_ now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "EEEE, yyyy-MM-dd"
        return formatter.string(from: now)
    }
}

extension ReminderStamp {
    /// The coming week for the model: `Tuesday 2026-09-08 (today)`,
    /// `Wednesday 2026-09-09 (tomorrow)`, then five more, one per line, so
    /// a weekday in a note is a lookup and not arithmetic.
    static func week(from now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "EEEE yyyy-MM-dd"
        return (0..<7).compactMap { offset -> String? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
            let note = offset == 0 ? " (today)" : offset == 1 ? " (tomorrow)" : ""
            return formatter.string(from: day) + note
        }.joined(separator: "\n")
    }
}
