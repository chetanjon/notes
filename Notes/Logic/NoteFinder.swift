import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Ask the note": when a search finds nothing by its letters, Apple's
/// on-device model reads the notes and picks the ones that answer the
/// question, with a one-line answer. iOS 26 with Apple Intelligence only;
/// elsewhere `isAvailable` is false and search stays what it was. The
/// notes never leave the phone. App only.
enum NoteFinder {
    /// One note as the model sees it.
    struct Card: Equatable {
        var id: UUID
        var text: String
    }

    struct Found: Equatable {
        var answer: String
        var ids: [UUID]
    }

    /// The model's context is small: this many notes at most, the likeliest
    /// first, each cut to `cardLimit` characters on one line.
    static let maxCards = 15
    static let cardLimit = 240
    static let answerLimit = 25

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        return OnDevice.isAvailable
        #else
        return false
        #endif
    }

    /// The cards most likely to answer the question first: those sharing
    /// the most words with it, ties in the order given (the list's own,
    /// most recent first). A card sharing nothing keeps its place after
    /// those that share something.
    static func rank(_ cards: [Card], for question: String) -> [Card] {
        let scored = cards.enumerated().map { index, card in
            (card: card, score: overlap(card, with: question), index: index)
        }
        return scored.sorted { a, b in
            a.score != b.score ? a.score > b.score : a.index < b.index
        }.map(\.card)
    }

    /// How many of the question's words the card has. A card with none
    /// cannot be the answer, whatever the model says: "wifi password" is
    /// not answered by a shopping list.
    static func overlap(_ card: Card, with question: String) -> Int {
        ModelGuard.words(card.text).intersection(ModelGuard.words(question)).count
    }

    static func find(_ question: String, in cards: [Card]) async -> Found? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, !cards.isEmpty {
            let likely = rank(cards, for: question).prefix(maxCards).filter { overlap($0, with: question) > 0 }
            // Nothing shares a word with the question: nothing answers it,
            // and the model is not asked.
            guard !likely.isEmpty else { return Found(answer: "", ids: []) }
            if let found = try? await Model.find(question, in: Array(likely)) {
                return found
            }
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    enum Model {
        @Generable
        struct Picks {
            @Guide(description: "The numbers of the notes that answer the question, best first. Empty when none does.", .maximumCount(5))
            var notes: [Int]
            @Guide(description: "One short sentence answering the question in the notes' own words. Empty when no note answers it.")
            var answer: String
        }

        static func find(_ question: String, in cards: [Card]) async throws -> Found {
            let listing = cards.enumerated()
                .map { "\($0.offset + 1). \(NoteText.oneLine($0.element.text, limit: cardLimit))" }
                .joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                The user asks a question about their own notes, given as a numbered list. Pick \
                the notes that answer it, best first, and answer in one short sentence using \
                only what those notes say, in the language of the question. If no note answers \
                it, pick none and leave the answer empty. Do not guess.

                Example question: when is the dentist
                Notes:
                1. Groceries: milk, eggs, bread
                2. This week: call the dentist tuesday, rent on the 1st
                3. Book ideas: a novel about a lighthouse
                Gives: notes 2; answer "Call the dentist Tuesday."

                Example question: what was the wifi password
                Notes:
                1. Groceries: milk, eggs
                2. Walking app idea: record voice while walking
                Gives: no notes; answer empty
                """)
            let response = try await session.respond(
                to: "Question: \(question)\n\nNotes:\n\(listing)", generating: Picks.self,
                options: OnDevice.Model.options)
            let ids = response.content.notes
                .filter { $0 >= 1 && $0 <= cards.count }
                .map { cards[$0 - 1].id }
            var seen = Set<UUID>()
            let unique = ids.filter { seen.insert($0).inserted }
            var answer = response.content.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if ModelGuard.wordCount(answer) > answerLimit { answer = "" }
            return Found(answer: unique.isEmpty ? "" : answer, ids: unique)
        }
    }
    #endif
}
