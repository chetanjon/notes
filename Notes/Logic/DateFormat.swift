import Foundation

/// The "when" of a note.
///
/// `when`, the short form for a Trash row: today the time (`9:14 AM`), the
/// last six days a weekday (`Thu`), the same year a date (`Aug 28`), and
/// anything older the year too (`Aug 28, 2025`). `stamp`, the line at the
/// top of the editor, is the same day with the time after it: `Today at
/// 9:14 AM`, `Thursday at 9:14 AM`, `Aug 28 at 9:14 AM`, `Aug 28, 2025 at
/// 9:14 AM`. Every form follows the user's locale.
enum DateFormat {
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current,
                     locale: Locale = .current) -> String {
        switch day(of: date, now: now, calendar: calendar) {
        case .today:
            return formatter(.time, calendar: calendar, locale: locale).string(from: date)
        case .thisWeek:
            return formatter(.weekday, calendar: calendar, locale: locale).string(from: date)
        case .thisYear:
            return formatter(.monthDay, calendar: calendar, locale: locale).string(from: date)
        case .older:
            return formatter(.monthDayYear, calendar: calendar, locale: locale).string(from: date)
        }
    }

    static func stamp(_ date: Date, now: Date = .now, calendar: Calendar = .current,
                      locale: Locale = .current) -> String {
        let time = formatter(.time, calendar: calendar, locale: locale).string(from: date)
        let day: String
        switch self.day(of: date, now: now, calendar: calendar) {
        case .today:
            day = "Today"
        case .thisWeek:
            day = formatter(.fullWeekday, calendar: calendar, locale: locale).string(from: date)
        case .thisYear:
            day = formatter(.monthDay, calendar: calendar, locale: locale).string(from: date)
        case .older:
            day = formatter(.monthDayYear, calendar: calendar, locale: locale).string(from: date)
        }
        return "\(day) at \(time)"
    }

    private enum Day { case today, thisWeek, thisYear, older }

    private static func day(of date: Date, now: Date, calendar: Calendar) -> Day {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDay, to: startOfToday).day ?? .max
        if days > 0, days <= 6 { return .thisWeek }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return sameYear ? .thisYear : .older
    }

    private enum Style: String {
        case time, weekday, fullWeekday, monthDay, monthDayYear
    }

    /// One formatter per style, locale and calendar, made once. A row is
    /// drawn many times a second while scrolling; a `DateFormatter` costs
    /// milliseconds to make. A locale change is a new key, so no
    /// notification is needed.
    private static var cache: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    private static func formatter(_ style: Style, calendar: Calendar, locale: Locale) -> DateFormatter {
        let key = "\(style.rawValue)|\(locale.identifier)|\(calendar.identifier)|\(calendar.timeZone.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch style {
        case .time:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        case .weekday:
            formatter.setLocalizedDateFormatFromTemplate("EEE")
        case .fullWeekday:
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
        case .monthDay:
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        case .monthDayYear:
            formatter.setLocalizedDateFormatFromTemplate("MMM d y")
        }
        cache[key] = formatter
        return formatter
    }
}
