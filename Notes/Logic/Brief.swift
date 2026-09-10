import Foundation

/// "Where did I leave off?": what a note has settled, what is still open,
/// and what to do next, as the model reads it. Pure: the line is built and
/// tested without the model.
struct Brief: Equatable {
    var decided: [String]
    var open: [String]
    var next: String

    var isEmpty: Bool { decided.isEmpty && open.isEmpty && next.isEmpty }

    /// `Decided: October, $3,000 budget. Open: pick a hotel. Next: compare
    /// the two near the station.` Parts with nothing in them are left out.
    var line: String {
        var parts: [String] = []
        if !decided.isEmpty { parts.append("Decided: " + decided.joined(separator: ", ")) }
        if !open.isEmpty { parts.append("Open: " + open.joined(separator: ", ")) }
        let step = next.trimmingCharacters(in: .whitespacesAndNewlines)
        if !step.isEmpty { parts.append("Next: " + step) }
        return parts.map { $0.hasSuffix(".") ? $0 : $0 + "." }.joined(separator: " ")
    }

    /// Two parts that say the same thing share this much of their words.
    static let sameThing = 0.8

    /// Only items in the note's own words, trimmed, empties gone, and
    /// nothing said twice: an open item that is the next step, or a
    /// decided item that is also open or next, goes. Nil when nothing
    /// survives.
    static func kept(decided: [String], open: [String], next: String, from text: String) -> Brief? {
        func keep(_ items: [String]) -> [String] {
            items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
                .filter { !$0.isEmpty && ModelGuard.grounded($0, in: text) }
        }
        let step = next.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextStep = ModelGuard.grounded(step, in: text) ? step : ""
        let openItems = keep(open).filter { !same($0, nextStep) }
        let decidedItems = keep(decided).filter { item in
            !same(item, nextStep) && !openItems.contains { same(item, $0) }
        }
        let brief = Brief(decided: decidedItems, open: openItems, next: nextStep)
        return brief.isEmpty ? nil : brief
    }

    /// Whether two parts say the same thing: most of one's words are in
    /// the other's. Empty parts say nothing.
    static func same(_ a: String, _ b: String) -> Bool {
        guard !ModelGuard.words(a).isEmpty, !ModelGuard.words(b).isEmpty else { return false }
        return ModelGuard.kept(of: a, in: b) >= sameThing || ModelGuard.kept(of: b, in: a) >= sameThing
    }

    /// A note worth a brief: plain, with three body lines or more.
    static func wanted(for text: String) -> Bool {
        guard !NoteText.isChecklist(text) else { return false }
        return NoteText.bodyLines(text).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 3
    }

    /// Coming back after this long, the brief shows on its own.
    static let away: TimeInterval = 24 * 60 * 60
}

/// "You've thought about this before": an older note that bears on what is
/// being written, and what it said. Pure parts here.
enum Recall {
    /// Shared content words a candidate needs before the model is asked.
    static let minimumOverlap = 3
    /// Words the note being written needs before anything is looked up.
    static let minimumWords = 8
    static let maxCandidates = 5

    /// A quote is this many words at most.
    static let quoteWords = 14

    /// The line of the older note that the model's `said` points at: the
    /// one sharing the most content words with it, marker taken off, the
    /// title left out when there is more to the note. What the hint shows,
    /// so it is always a line the note contains and never the whole note
    /// run together. Nil when no line shares a word.
    static func quote(from text: String, near said: String) -> String? {
        let wanted = ModelGuard.words(said)
        guard !wanted.isEmpty else { return nil }
        var lines = text.split(separator: "\n")
            .map { Checklist.content(String($0)).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count > 1 { lines.removeFirst() }
        var best: (line: String, shared: Int)?
        for line in lines {
            let shared = ModelGuard.words(line).intersection(wanted).count
            if shared > (best?.shared ?? 0) { best = (line, shared) }
        }
        guard let best else { return nil }
        let words = best.line.split(whereSeparator: { $0.isWhitespace })
        if words.count <= quoteWords { return best.line }
        return words.prefix(quoteWords).joined(separator: " ") + "…"
    }

    /// The other notes most likely to bear on `writing`, best first, those
    /// sharing fewer than `minimumOverlap` words left out.
    static func candidates(for writing: String, among others: [NoteFinder.Card]) -> [NoteFinder.Card] {
        guard ModelGuard.words(writing).count >= minimumWords else { return [] }
        return Array(NoteFinder.rank(others, for: writing)
            .filter { NoteFinder.overlap($0, with: writing) >= minimumOverlap }
            .prefix(maxCandidates))
    }
}
