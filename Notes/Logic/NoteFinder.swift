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

    /// The model's context is small: this many notes at most, each cut to
    /// `cardLimit` characters on one line.
    static let maxCards = 40
    static let cardLimit = 240

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    static func find(_ question: String, in cards: [Card]) async -> Found? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, !cards.isEmpty,
           let found = try? await Model.find(question, in: Array(cards.prefix(maxCards))) {
            return found
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    enum Model {
        @Generable
        struct Picks {
            @Guide(description: "The numbers of the notes that answer the question, best first. Empty when none does.")
            var notes: [Int]
            @Guide(description: "One short sentence that answers the question using only those notes. Empty when no note does.")
            var answer: String
        }

        static func find(_ question: String, in cards: [Card]) async throws -> Found {
            let listing = cards.enumerated()
                .map { "\($0.offset + 1). \(NoteText.oneLine($0.element.text, limit: cardLimit))" }
                .joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                The user has a question and a numbered list of their notes. Pick the notes \
                that answer the question, best first, and answer in one short sentence using \
                only what the notes say. If no note answers it, pick none and leave the answer empty.
                """)
            let response = try await session.respond(
                to: "Question: \(question)\n\nNotes:\n\(listing)", generating: Picks.self)
            let ids = response.content.notes
                .filter { $0 >= 1 && $0 <= cards.count }
                .map { cards[$0 - 1].id }
            var seen = Set<UUID>()
            let unique = ids.filter { seen.insert($0).inserted }
            let answer = response.content.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            return Found(answer: unique.isEmpty ? "" : answer, ids: unique)
        }
    }
    #endif
}
