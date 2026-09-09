import Foundation

/// Checks on what the on-device model gives back, so only what it got
/// right is applied. Pure, so they are tested without the model.
enum ModelGuard {
    /// Words that say nothing about what a note is about.
    static let stopWords: Set<String> = [
        "the", "and", "for", "with", "when", "what", "where", "which", "who", "how",
        "this", "that", "these", "those", "was", "were", "are", "is", "not", "you",
        "your", "our", "its", "from", "into", "about", "then", "than", "but", "have",
        "has", "had", "did", "does", "will", "can", "could", "should", "would",
    ]

    /// The words that carry meaning: three letters or more, lowercased,
    /// accents dropped, the stop words left out.
    static func words(_ text: String) -> Set<String> {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return Set(folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) })
    }

    /// The candidate's words all occur in the source: nothing was invented.
    /// A candidate with no words of its own passes.
    static func sharesWords(_ candidate: String, with source: String) -> Bool {
        words(candidate).isSubset(of: words(source))
    }

    /// The share of the source's words that survive in the candidate.
    static func kept(of source: String, in candidate: String) -> Double {
        let from = words(source)
        guard !from.isEmpty else { return 1 }
        return Double(from.intersection(words(candidate)).count) / Double(from.count)
    }

    /// The same share, counting a word as surviving when the candidate has
    /// it or a near spelling of it. Fixing a misspelling removes the word
    /// as written, so a strict count reads "tomatos" becoming "tomatoes"
    /// as half the line lost, and the correction is refused: the one thing
    /// the check exists to allow.
    static func keptAllowingSpelling(of source: String, in candidate: String) -> Double {
        let from = words(source)
        guard !from.isEmpty else { return 1 }
        let to = words(candidate)
        let survived = from.filter { word in to.contains(word) || to.contains(where: { near(word, $0) }) }
        return Double(survived.count) / Double(from.count)
    }

    /// Two words are the same word differently spelt: one edit apart, or
    /// two for a long word. Cheap, and only ever asked about short words.
    static func near(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if abs(a.count - b.count) > 2 { return false }
        // Two letters the wrong way round is the commonest typo there is,
        // and plain Levenshtein charges two edits for it.
        if swapped(a, b) { return true }
        let allowed = min(a.count, b.count) >= 6 ? 2 : 1
        return distance(a, b, limit: allowed) <= allowed
    }

    /// The same letters with one neighbouring pair the wrong way round:
    /// "teh" for "the".
    static func swapped(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        guard x.count == y.count, x.count >= 2 else { return false }
        let differing = x.indices.filter { x[$0] != y[$0] }
        guard differing.count == 2, differing[1] == differing[0] + 1 else { return false }
        return x[differing[0]] == y[differing[1]] && x[differing[1]] == y[differing[0]]
    }

    /// Levenshtein distance, given up on once it passes `limit`.
    static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var row = Array(0...y.count)
        for i in 1...x.count {
            var previous = row[0]
            row[0] = i
            var best = row[0]
            for j in 1...y.count {
                let insert = row[j] + 1
                let delete = row[j - 1] + 1
                let swap = previous + (x[i - 1] == y[j - 1] ? 0 : 1)
                previous = row[j]
                row[j] = min(insert, delete, swap)
                best = min(best, row[j])
            }
            if best > limit { return limit + 1 }
        }
        return row[y.count]
    }

    /// The candidate says only what the source says: every content word of
    /// it is in the source, or near a word that is, and it says something
    /// at all. `sharesWords` is the strict form; this one lets an
    /// inflection through ("hotel" for "hotels") without letting an
    /// invention through, and refuses a candidate made only of small words,
    /// which the strict form waves past because its word set is empty.
    static func grounded(_ candidate: String, in source: String, keeping: Double = 0.75) -> Bool {
        let mine = words(candidate)
        guard !mine.isEmpty else { return false }
        let theirs = words(source)
        let found = mine.filter { word in theirs.contains(word) || theirs.contains(where: { near(word, $0) }) }
        return Double(found.count) / Double(mine.count) >= keeping
    }

    /// The two are about the same length in words, within `tolerance`. A
    /// tidied line that grew or shrank more than that was rewritten.
    static func lengthClose(_ a: String, _ b: String, tolerance: Double = 0.4) -> Bool {
        let na = a.split(whereSeparator: { $0.isWhitespace }).count
        let nb = b.split(whereSeparator: { $0.isWhitespace }).count
        if na == 0 || nb == 0 { return na == nb }
        let longer = Double(max(na, nb))
        return Double(abs(na - nb)) / longer <= tolerance
    }

    /// Whether a tidied line is the same line, cleaned: still empty or still
    /// not, at least `keeping` of its content words kept, grown by no more
    /// than half (plus one word), and none of its neighbours' words pulled
    /// in. Fails, and the original stays, when the model rewrote the line
    /// or ran two lines together.
    static func tidyKeeps(_ was: String, _ now: String, others: [String], keeping: Double = 0.6) -> Bool {
        let before = was.trimmingCharacters(in: .whitespaces)
        let after = now.trimmingCharacters(in: .whitespaces)
        if before.isEmpty || after.isEmpty { return before.isEmpty == after.isEmpty }
        guard keptAllowingSpelling(of: before, in: after) >= keeping else { return false }
        guard Double(wordCount(after)) <= Double(wordCount(before)) * 1.5 + 1 else { return false }
        return !absorbs(after, own: before, from: others)
    }

    /// Whether `candidate` took words from another line: two or more of a
    /// neighbour's content words that its own original did not have.
    static func absorbs(_ candidate: String, own: String, from others: [String]) -> Bool {
        let mine = words(own)
        let has = words(candidate)
        return others.contains { other in
            words(other).subtracting(mine).intersection(has).count >= 2
        }
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
