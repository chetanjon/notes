import Foundation

/// Finds the things in a note that have a day or a time, without a model:
/// "dentist tuesday 3pm", "call mum tomorrow at 10", "rent due on the
/// 1st", "in twenty minutes". Each line is looked at on its own, and a
/// line with several things separated by slashes or semicolons is looked
/// at piece by piece. Pure, so it is tested without a phone; the model's
/// findings are merged with these where there is a model, and on other
/// iPhones this is all of "Reminders".
enum DateSpotter {
    struct Hit: Equatable {
        var title: String
        var due: Date
    }

    /// The pieces of the text a date could sit in: lines, and within a
    /// line the parts between " / ", ";" and " · ", markers and bullets
    /// taken off, blanks dropped.
    static func segments(of text: String) -> [String] {
        var result: [String] = []
        let cuts = try? NSRegularExpression(pattern: "\\s+/\\s+|;|\\s+[·•]\\s+")
        for line in text.split(separator: "\n") {
            let bare = Checklist.content(String(line))
            let parts: [String]
            if let cuts {
                let ns = bare as NSString
                var pieces: [String] = []
                var start = 0
                for match in cuts.matches(in: bare, range: NSRange(location: 0, length: ns.length)) {
                    pieces.append(ns.substring(with: NSRange(location: start, length: match.range.location - start)))
                    start = NSMaxRange(match.range)
                }
                pieces.append(ns.substring(from: start))
                parts = pieces
            } else {
                parts = [bare]
            }
            for part in parts {
                let piece = strippingBullet(part.trimmingCharacters(in: .whitespaces))
                if !piece.isEmpty { result.append(piece) }
            }
        }
        return result
    }

    /// Every segment with a day or a time, as a title and when it is due.
    static func find(in text: String, now: Date = .now, calendar: Calendar = .current) -> [Hit] {
        segments(of: text).compactMap { spot($0, now: now, calendar: calendar) }
    }

    // MARK: One segment

    private struct Match {
        var range: NSRange
        var kind: Kind
        enum Kind {
            case day(Int, at: Int?)    // days from today, and a soft hour
            case weekday(Int, next: Bool)
            case dayOfMonth(Int)
            case monthDay(month: Int, day: Int)
            case time(hour: Int, minute: Int)
            case bareHour(Int)         // "friday 8": an hour only if a day was given
            case period(hour: Int)     // morning, evening: a time, but a soft one
            case interval(TimeInterval)
        }
    }

    private static let weekdays = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]
    private static let months = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
                                 "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
    private static let numberWords = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                                      "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
                                      "twelve": 12, "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40,
                                      "fifty": 50, "sixty": 60]
    private static let periods = ["morning": 9, "afternoon": 14, "evening": 18, "night": 20]

    private static let monthPattern = "jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?"

    /// The patterns, most specific first; a later match that overlaps an
    /// earlier one is dropped, so "3.30pm" is never also "at 3".
    private static let patterns: [(String, ([String]) -> Match.Kind?)] = [
        // in twenty minutes, in an hour, in 2 days
        ("\\bin\\s+(\\d{1,3}|a|an|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|fifteen|twenty|thirty|forty|fifty|sixty|half an)\\s+(minutes?|mins?|hours?|hrs?|days?)\\b", { g in
            let unit = g[2].hasPrefix("m") ? 60.0 : g[2].hasPrefix("h") ? 3600.0 : 86400.0
            let count: Double
            if g[1] == "half an" { count = 0.5 } else if let n = Int(g[1]) { count = Double(n) }
            else if let n = numberWords[g[1]] { count = Double(n) } else { return nil }
            return .interval(count * unit)
        }),
        // 1 October, 1st of October, October 1, Oct 1st
        ("\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?(\(monthPattern))\\b", { g in
            guard let day = Int(g[1]), let month = months[String(g[2].prefix(3))] else { return nil }
            return .monthDay(month: month, day: day)
        }),
        ("\\b(\(monthPattern))\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b", { g in
            guard let day = Int(g[2]), let month = months[String(g[1].prefix(3))] else { return nil }
            return .monthDay(month: month, day: day)
        }),
        // on the 1st, the 15th
        ("\\b(?:on\\s+)?(?:the\\s+)?(\\d{1,2})(?:st|nd|rd|th)\\b", { g in
            guard let day = Int(g[1]) else { return nil }
            return .dayOfMonth(day)
        }),
        // 15:00, 3:30 pm, and 3.30pm only with am/pm: a bare "2.20" is a price
        ("\\b(?:at\\s+)?(\\d{1,2}):(\\d{2})\\s*(am|pm|a\\.m\\.|p\\.m\\.)?\\b", { g in
            guard let hour = Int(g[1]), let minute = Int(g[2]), hour <= 23, minute <= 59 else { return nil }
            return .time(hour: clock(hour, meridiem: g[3]), minute: minute)
        }),
        ("\\b(?:(at)\\s+)?(\\d{1,2})\\.(\\d{2})\\s*(am|pm|a\\.m\\.|p\\.m\\.)?", { g in
            // "bread 2.20" is money; only "at 2.20" or "2.20pm" is a time.
            guard !g[4].isEmpty || !g[1].isEmpty else { return nil }
            guard let hour = Int(g[2]), let minute = Int(g[3]), hour <= 23, minute <= 59 else { return nil }
            return .time(hour: clock(hour, meridiem: g[4]), minute: minute)
        }),
        // 3pm, 3 pm, 10am
        ("\\b(?:at\\s+)?(\\d{1,2})\\s*(am|pm|a\\.m\\.|p\\.m\\.)(?![a-z])", { g in
            guard let hour = Int(g[1]), hour <= 12 else { return nil }
            return .time(hour: clock(hour, meridiem: g[2]), minute: 0)
        }),
        // at 3
        ("\\bat\\s+(\\d{1,2})\\b(?![:.]\\d)", { g in
            guard let hour = Int(g[1]), hour <= 23 else { return nil }
            return .time(hour: clock(hour, meridiem: ""), minute: 0)
        }),
        ("\\b(noon|midday)\\b", { _ in .time(hour: 12, minute: 0) }),
        ("\\bmidnight\\b", { _ in .time(hour: 24, minute: 0) }),
        // tomorrow, today, tonight, this evening, tomorrow morning
        ("\\b(today|tomorrow|tonight|this\\s+(?:morning|afternoon|evening)|tomorrow\\s+(?:morning|afternoon|evening|night))\\b", { g in
            let words = g[1].split(whereSeparator: { $0.isWhitespace }).map(String.init)
            if words.count == 2, let hour = periods[words[1]] {
                return .day(words[0] == "tomorrow" ? 1 : 0, at: hour)
            }
            if g[1] == "tonight" { return .day(0, at: periods["night"]) }
            return .day(g[1] == "tomorrow" ? 1 : 0, at: nil)
        }),
        // tuesday, next tuesday, tues, thu
        ("\\b(?:(next)\\s+)?(mon(?:day)?|tues?(?:day)?|wed(?:nesday)?|thu(?:rs?|rsday)?|fri(?:day)?|saturday|sunday)\\b", { g in
            guard let weekday = weekdays[String(g[2].prefix(3))] else { return nil }
            return .weekday(weekday, next: g[1] == "next")
        }),
        // in the morning, this evening on its own
        ("\\b(?:in\\s+the\\s+)?(morning|afternoon|evening)\\b", { g in
            guard let hour = periods[g[1]] else { return nil }
            return .period(hour: hour)
        }),
        // "gym friday 8": a bare hour, used only when a day was named too
        ("\\b(\\d{1,2})\\b(?![:.,]\\d)", { g in
            guard let hour = Int(g[1]), hour <= 23 else { return nil }
            return .bareHour(hour)
        }),
    ]

    /// Built once: a segment of a long note would otherwise recompile every
    /// pattern, and Reminders reads every line of the note.
    private static let compiled: [(regex: NSRegularExpression, kind: ([String]) -> Match.Kind?)] =
        patterns.compactMap { pattern, make in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return (regex, make)
        }

    /// An hour on the 24-hour clock: "3pm" is 15; "3" alone is 15 too, and
    /// "9" alone is 9, since a bare hour under seven is an afternoon one.
    private static func clock(_ hour: Int, meridiem: String) -> Int {
        let m = meridiem.lowercased().replacingOccurrences(of: ".", with: "")
        if m == "am" { return hour == 12 ? 0 : hour }
        if m == "pm" { return hour == 12 ? 12 : hour + 12 }
        return (1...6).contains(hour) ? hour + 12 : hour
    }

    private static func spot(_ segment: String, now: Date, calendar: Calendar) -> Hit? {
        let ns = segment as NSString
        var matches: [Match] = []
        for (regex, make) in compiled {
            for found in regex.matches(in: segment, range: NSRange(location: 0, length: ns.length)) {
                guard !matches.contains(where: { NSIntersectionRange($0.range, found.range).length > 0 }) else { continue }
                // The groups are read lowercased, but the ranges belong to
                // the segment as written: lowercasing the whole string first
                // would shift them, since "İ" grows a unit when it folds.
                let groups = (0..<found.numberOfRanges).map { i -> String in
                    let r = found.range(at: i)
                    return r.location == NSNotFound ? "" : ns.substring(with: r).lowercased()
                }
                if let kind = make(groups) { matches.append(Match(range: found.range, kind: kind)) }
            }
        }
        // In the order they were written, not the order the patterns are
        // tried, so "tuesday, rent on the 1st" reads left to right.
        matches.sort { $0.range.location < $1.range.location }
        guard let due = when(matches.map(\.kind), now: now, calendar: calendar) else { return nil }
        return Hit(title: title(of: segment, without: matches.map(\.range)), due: due)
    }

    /// The moment the matches add up to: a day (today when only a time was
    /// given), and a time (nine in the morning when only a day was). A time
    /// today that has passed means tomorrow; a weekday that is today and
    /// past means next week. Nil when there is neither day nor time.
    private static func when(_ kinds: [Match.Kind], now: Date, calendar: Calendar) -> Date? {
        var day: Date?
        var time: (hour: Int, minute: Int)?
        var soft: Int?
        var bare: Int?
        var ahead: TimeInterval?
        var dayIsExplicit = false
        var weekdayGiven = false
        for kind in kinds {
            switch kind {
            case let .interval(seconds):
                if ahead == nil { ahead = seconds }
            case let .day(offset, at: hour):
                day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))
                dayIsExplicit = true
                if let hour, soft == nil { soft = hour }
            case let .weekday(weekday, next):
                let today = calendar.component(.weekday, from: now)
                var forward = (weekday - today + 7) % 7
                if next, forward == 0 { forward = 7 }
                day = calendar.date(byAdding: .day, value: forward, to: calendar.startOfDay(for: now))
                dayIsExplicit = true
                weekdayGiven = true
            case let .dayOfMonth(number):
                guard let found = nextDate(day: number, from: now, calendar: calendar) else { continue }
                day = found
                dayIsExplicit = true
            case let .monthDay(month, number):
                let year = calendar.component(.year, from: now)
                guard var found = date(year: year, month: month, day: number, calendar: calendar) else { continue }
                if found < calendar.startOfDay(for: now),
                   let nextYear = date(year: year + 1, month: month, day: number, calendar: calendar) {
                    found = nextYear
                }
                day = found
                dayIsExplicit = true
            case let .time(hour, minute):
                if time == nil { time = (hour, minute) }
            case let .bareHour(hour):
                if bare == nil { bare = hour }
            case let .period(hour):
                if soft == nil { soft = hour }
            }
        }
        // "in twenty minutes" with no day and no clock time is that far off.
        if let ahead, day == nil, time == nil { return now.addingTimeInterval(ahead) }
        // A bare number is an hour only next to a day: "gym friday 8".
        if time == nil, dayIsExplicit, let bare { time = (clock(bare, meridiem: ""), 0) }
        // A period alone ("morning pages") is not a date.
        guard day != nil || time != nil else { return nil }
        var base = day ?? calendar.startOfDay(for: now)
        if let ahead, day == nil {
            base = calendar.startOfDay(for: now.addingTimeInterval(ahead))
        }
        let at = time ?? (soft.map { ($0, 0) } ?? (ReminderStamp.morning, 0))
        guard var due = calendar.date(byAdding: DateComponents(hour: at.hour, minute: at.minute), to: base) else { return nil }
        if due <= now {
            if !dayIsExplicit, ahead == nil, let next = calendar.date(byAdding: .day, value: 1, to: due) { due = next }
            else if weekdayGiven, let next = calendar.date(byAdding: .day, value: 7, to: due) { due = next }
        }
        return due
    }

    /// That day of the month, this month or the first later month that has
    /// it: "the 31st" in September is 31 October, not 1 October, which is
    /// what building the date and letting it overflow would give.
    private static func nextDate(day number: Int, from now: Date, calendar: Calendar) -> Date? {
        guard (1...31).contains(number) else { return nil }
        let today = calendar.startOfDay(for: now)
        var month = today
        for _ in 0..<14 {
            let parts = calendar.dateComponents([.year, .month], from: month)
            if let year = parts.year, let m = parts.month,
               let found = date(year: year, month: m, day: number, calendar: calendar), found >= today {
                return found
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return nil }
            month = next
        }
        return nil
    }

    /// That date, or nil when the month has no such day: a calendar builds
    /// 31 September as 1 October rather than refusing it.
    private static func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day),
              let made = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.day, from: made) == day else { return nil }
        return made
    }

    /// The segment with the date words taken out and the joining words they
    /// leave behind ("call mum at", "rent due on the"), tidied; the segment
    /// itself when nothing is left.
    private static func title(of segment: String, without ranges: [NSRange]) -> String {
        let ns = NSMutableString(string: segment)
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            ns.replaceCharacters(in: range, with: " ")
        }
        var text = ns as String
        let dangling = "\\s*\\b(?:at|on|in|the|of|by|from|next|this|for|until|till)\\b\\s*$"
        if let regex = try? NSRegularExpression(pattern: dangling, options: .caseInsensitive) {
            var previous = ""
            while previous != text {
                previous = text
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }
        let cleaned = NoteText.tidied(text.trimmingCharacters(in: CharacterSet(charactersIn: " ,.-:;–")))
        return cleaned.isEmpty ? NoteText.tidied(segment) : cleaned
    }

    /// "- milk", "• milk", "1. milk" → "milk".
    private static func strippingBullet(_ line: String) -> String {
        var item = line
        for bullet in ["- ", "• ", "* ", "– "] where item.hasPrefix(bullet) {
            item = String(item.dropFirst(bullet.count))
        }
        return item.trimmingCharacters(in: .whitespaces)
    }
}
