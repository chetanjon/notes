import Foundation

/// The "when" in a list row.
///
/// Today shows the time (`9:14 AM`), the last six days a weekday (`Thu`),
/// the same year a date (`Aug 28`), and anything older the year too
/// (`Aug 28, 2025`). Every form follows the user's locale.
enum DateFormat {
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current,
                     locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return formatter(.time, calendar: calendar, locale: locale).string(from: date)
        }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDay, to: startOfToday).day ?? .max
        if days > 0, days <= 6 {
            return formatter(.weekday, calendar: calendar, locale: locale).string(from: date)
        }

        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return formatter(sameYear ? .monthDay : .monthDayYear, calendar: calendar, locale: locale)
            .string(from: date)
    }

    private enum Style: String {
        case time, weekday, monthDay, monthDayYear
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
        case .monthDay:
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        case .monthDayYear:
            formatter.setLocalizedDateFormatFromTemplate("MMM d y")
        }
        cache[key] = formatter
        return formatter
    }
}
