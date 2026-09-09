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

    /// Only items in the note's own words, trimmed, empties gone; nil when
    /// nothing survives.
    static func kept(decided: [String], open: [String], next: String, from text: String) -> Brief? {
        func keep(_ items: [String]) -> [String] {
            items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
                .filter { !$0.isEmpty && ModelGuard.sharesWords($0, with: text) }
        }
        let step = next.trimmingCharacters(in: .whitespacesAndNewlines)
        let brief = Brief(decided: keep(decided), open: keep(open),
                          next: ModelGuard.sharesWords(step, with: text) ? step : "")
        return brief.isEmpty ? nil : brief
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

    /// The other notes most likely to bear on `writing`, best first, those
    /// sharing fewer than `minimumOverlap` words left out.
    static func candidates(for writing: String, among others: [NoteFinder.Card]) -> [NoteFinder.Card] {
        guard ModelGuard.words(writing).count >= minimumWords else { return [] }
        return Array(NoteFinder.rank(others, for: writing)
            .filter { NoteFinder.overlap($0, with: writing) >= minimumOverlap }
            .prefix(maxCandidates))
    }
}
