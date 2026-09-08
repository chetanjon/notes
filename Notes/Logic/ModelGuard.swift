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

    /// The two are about the same length in words, within `tolerance`. A
    /// tidied line that grew or shrank more than that was rewritten.
    static func lengthClose(_ a: String, _ b: String, tolerance: Double = 0.4) -> Bool {
        let na = a.split(whereSeparator: { $0.isWhitespace }).count
        let nb = b.split(whereSeparator: { $0.isWhitespace }).count
        if na == 0 || nb == 0 { return na == nb }
        let longer = Double(max(na, nb))
        return Double(abs(na - nb)) / longer <= tolerance
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
