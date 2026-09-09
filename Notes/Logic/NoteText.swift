import Foundation

/// Everything the app derives from a note's text: its title, its preview,
/// its checklist tally. Pure functions on a `String`, so the `Note` model
/// stays a thin wrapper and all of this is testable without SwiftData.
enum NoteText {
    static let untitled = "New note"

    static func lines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// The first non-empty line, marker stripped. "New note" when there is none.
    static func title(_ text: String) -> String {
        lines(text)
            .map { Checklist.content($0).trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? untitled
    }

    /// Every line after the first.
    static func bodyLines(_ text: String) -> [String] {
        Array(lines(text).dropFirst())
    }

    static func isChecklist(_ text: String) -> Bool {
        bodyLines(text).contains(where: Checklist.isItem)
    }

    struct Summary: Equatable {
        var done: Int
        var total: Int
        var open: [String]
    }

    /// Counts the items in the body. `open` holds the open items' text, in order.
    static func checklistSummary(_ text: String) -> Summary {
        var summary = Summary(done: 0, total: 0, open: [])
        for line in bodyLines(text) where Checklist.isItem(line) {
            summary.total += 1
            if Checklist.isDone(line) {
                summary.done += 1
            } else {
                let item = Checklist.content(line).trimmingCharacters(in: .whitespaces)
                if !item.isEmpty { summary.open.append(item) }
            }
        }
        return summary
    }

    /// What Siri says for "What's on Groceries": the open items, or for a
    /// plain note its first lines, or that there is nothing.
    static func spoken(_ text: String) -> String {
        let name = title(text)
        if isChecklist(text) {
            let s = checklistSummary(text)
            if s.open.isEmpty { return "Everything on \(name) is done." }
            let list = spokenList(s.open)
            return s.open.count == 1
                ? "One thing left on \(name): \(list)."
                : "\(s.open.count) left on \(name): \(list)."
        }
        let body = bodyLines(text)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(5)
        if body.isEmpty { return "\(name) has nothing under the title." }
        return "\(name): " + body.joined(separator: ". ")
    }

    /// "milk", "milk and eggs", "milk, eggs, and bread".
    static func spokenList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }

    /// The single line under a title in the list.
    ///
    /// Plain note: every line after the first, joined with spaces. Checklist:
    /// `"1/4 done · eggs, milk"`, or `"All done"`.
    static func preview(_ text: String) -> String {
        if isChecklist(text) {
            let s = checklistSummary(text)
            if s.done == s.total { return "All done" }
            return "\(s.done)/\(s.total) done · \(s.open.joined(separator: ", "))"
        }
        return bodyLines(text)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// What the widget shows under the title: the first line of the body,
    /// or `"2/5 · milk, eggs"` for a checklist.
    static func widgetPreview(_ text: String) -> String {
        if isChecklist(text) {
            let s = checklistSummary(text)
            if s.done == s.total { return "All done" }
            return "\(s.done)/\(s.total) · \(s.open.joined(separator: ", "))"
        }
        return bodyLines(text)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    /// A plain note whose first line would not do on the Lock Screen: two
    /// body lines or more, or one long one. Such a note gets a one-line
    /// summary on the card where there is a model to write it.
    static func wantsSummary(_ text: String, longLine: Int = 60) -> Bool {
        guard !isChecklist(text) else { return false }
        let body = bodyLines(text)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return body.count >= 2 || (body.first?.count ?? 0) > longLine
    }

    struct Counter: Equatable {
        var label: String
        var value: Int
        var lineIndex: Int
    }

    /// A body line that ends in a number, with a label before it that has no
    /// digit of its own: "Water 3", "Pushups 20". Never a checklist item.
    /// The Lock Screen gives such a line a + that edits the number.
    static func counters(_ text: String) -> [Counter] {
        var found: [Counter] = []
        for (index, line) in lines(text).enumerated().dropFirst() {
            if let counter = counter(in: line, at: index) { found.append(counter) }
        }
        return found
    }

    private static func counter(in line: String, at index: Int) -> Counter? {
        // The first line is the title, never a counter.
        guard index > 0, !Checklist.isItem(line) else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let space = trimmed.lastIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
        let label = trimmed[..<space].trimmingCharacters(in: .whitespaces)
        let digits = trimmed[trimmed.index(after: space)...]
        guard !label.isEmpty, !label.contains(where: { $0.isNumber }),
              !digits.isEmpty, digits.count <= 6, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(digits) else { return nil }
        return Counter(label: String(label), value: value, lineIndex: index)
    }

    /// The text with the counter on line `lineIndex` moved by `delta`, never
    /// below zero, the spacing between label and number kept. Nil when that
    /// line is not a counter.
    static func stepping(counterAt lineIndex: Int, by delta: Int, in text: String) -> String? {
        var all = lines(text)
        guard all.indices.contains(lineIndex),
              let counter = counter(in: all[lineIndex], at: lineIndex) else { return nil }
        let line = all[lineIndex]
        // Replace only the digits, so indentation and spacing stay.
        let trailing = line.reversed().prefix(while: { $0 == " " || $0 == "\t" }).count
        let core = line.dropLast(trailing)
        guard let digitsStart = core.lastIndex(where: { !$0.isNumber }) else { return nil }
        let head = String(core[...digitsStart])
        all[lineIndex] = head + String(max(0, counter.value + delta)) + String(line.suffix(trailing))
        return all.joined(separator: "\n")
    }

    /// The counters the Lock Screen card carries: the first few, in note
    /// order. A checklist's items are not on the card; only its count is.
    static func pinnedCounters(_ text: String, limit: Int = PinStore.maxCounters) -> [PinnedCounter] {
        counters(text).prefix(max(0, limit)).map {
            PinnedCounter(label: $0.label, value: $0.value, line: $0.lineIndex)
        }
    }

    /// Only whitespace and bare markers. Such a note is discarded on dismiss.
    static func isBlank(_ text: String) -> Bool {
        lines(text).allSatisfy {
            Checklist.content($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// The text as one line, markers off, whitespace collapsed, cut at
    /// `limit` characters with an ellipsis. What the on-device model reads
    /// of a note when asked a question.
    static func oneLine(_ text: String, limit: Int) -> String {
        let words = lines(text)
            .map(Checklist.content)
            .joined(separator: " ")
            .split(whereSeparator: { $0.isWhitespace })
        let joined = words.joined(separator: " ")
        guard joined.count > limit else { return joined }
        return String(joined.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// The line with its first letter in capitals and the pronoun "i" as
    /// "I": what Tidy up does on its own, whatever the model gave back.
    static func capitalised(_ line: String) -> String {
        var result = line
        if let first = result.firstIndex(where: { $0.isLetter }),
           result[..<first].allSatisfy({ $0.isWhitespace || $0.isPunctuation || $0 == "\u{25A1}" || $0 == "\u{25A0}" }) {
            result.replaceSubrange(first...first, with: String(result[first]).uppercased())
        }
        // A lone "i" between spaces or at the ends: "i think" and "so i".
        let pattern = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}'’])i(?![\\p{L}\\p{N}'’])")
        if let pattern {
            let range = NSRange(result.startIndex..., in: result)
            result = pattern.stringByReplacingMatches(in: result, range: range, withTemplate: "I")
        }
        return result
    }

    /// The line as a careful typist would leave it, without a model: the
    /// first letter and the pronoun "I" capitalised, no space before a
    /// comma or a full stop, one space after a comma, doubled spaces
    /// collapsed, the ends trimmed. What "Tidy up" does on every line,
    /// after the model where there is one and instead of it where not.
    static func tidied(_ line: String) -> String {
        var result = line.trimmingCharacters(in: .whitespaces)
        let rules: [(String, String)] = [
            ("[ \\t]{2,}", " "),
            ("\\s+([,.!?;:])", "$1"),
            (",(?=[^\\s\\d])", ", "),
        ]
        for (pattern, template) in rules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: template)
        }
        return capitalised(result)
    }

    /// Words a question starts with.
    static let questionWords: Set<String> = [
        "when", "what", "where", "who", "whose", "whom", "how", "which", "why",
        "is", "are", "was", "were", "do", "does", "did", "can", "could", "has", "have", "will", "should",
    ]

    /// Whether a search reads as a question rather than a word to find:
    /// it ends in a question mark, or starts with a question word and has
    /// more than that word. "when is the dentist" is one; "dentist" is not.
    static func isQuestion(_ query: String) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("?") { return true }
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" })
        guard words.count >= 2, let first = words.first else { return false }
        return questionWords.contains(String(first))
    }

    /// Case-insensitive search over the whole text.
    static func matches(_ text: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
