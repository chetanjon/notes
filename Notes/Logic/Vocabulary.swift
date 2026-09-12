import Foundation

/// The words in someone's own notes that a general speech model would get
/// wrong: the names of people, places and things they write down often.
/// Handed to the recogniser before listening, they come back spelled the
/// way the user spells them rather than as the nearest common word.
///
/// A capital is the only clue available without a model, so the rule is
/// that a capital means a name only when the word does not begin a
/// sentence. That leaves out "Milk" at the head of a line, which every
/// note is full of, and keeps "Priya" in the middle of one.
///
/// Pure, so it is tested without the microphone.
enum Vocabulary {
    /// Enough to cover the names someone actually uses. The list is ranked,
    /// so the cap drops the rarest.
    static let limit = 100
    /// How far back to read. The names someone uses are in what they have
    /// written lately, and reading everything would cost more than it adds.
    static let notesRead = 40

    static func terms(in texts: [String], limit: Int = limit) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for text in texts {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                // A checklist marker would otherwise make the real first
                // word look like the second.
                let content = Checklist.content(String(line))
                var startsSentence = true
                for word in content.split(whereSeparator: { $0.isWhitespace }) {
                    let raw = String(word)
                    let bare = raw.trimmingCharacters(in: .punctuationCharacters)
                    if !startsSentence, isName(bare) {
                        if counts[bare] == nil { order.append(bare) }
                        counts[bare, default: 0] += 1
                    }
                    startsSentence = endsSentence(raw)
                }
            }
        }
        // Most written first, and among equals the one written first, so
        // the cap is not decided by the order a dictionary happened to be in.
        let ranked = order.enumerated().sorted { one, two in
            let first = counts[one.element] ?? 0
            let second = counts[two.element] ?? 0
            return first == second ? one.offset < two.offset : first > second
        }
        return ranked.prefix(max(0, limit)).map(\.element)
    }

    /// A capitalised word of at least two letters. One letter is an initial
    /// or a flat number, and a digit is not a name at all.
    private static func isName(_ word: String) -> Bool {
        guard word.count >= 2, word.first?.isUppercase == true else { return false }
        return word.allSatisfy { $0.isLetter || $0 == "'" || $0 == "’" || $0 == "-" }
    }

    /// Closing quotes and brackets sit outside the full stop, so they are
    /// looked past rather than treated as the last character.
    private static let closers: Set<Character> = [")", "]", "}", "\"", "'", "”", "’", "»"]

    private static func endsSentence(_ word: String) -> Bool {
        guard let last = word.last(where: { !closers.contains($0) }) else { return false }
        return last == "." || last == "!" || last == "?"
    }
}
