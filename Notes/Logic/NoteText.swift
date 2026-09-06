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

    /// Case-insensitive search over the whole text.
    static func matches(_ text: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
