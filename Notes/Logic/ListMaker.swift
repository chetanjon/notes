import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Make a list": the items in a stretch of plain text. On an iPhone with
/// Apple Intelligence, Apple's on-device model does it, one item per task
/// in the writer's own words, and the text never leaves the phone. On any
/// other phone, or when the model has nothing to give, `Checklist.split`
/// does it with commas, "and", and line breaks. App only.
enum ListMaker {
    /// The model's context is small; past this, the rule does the work.
    private static let modelLimit = 6000
    static let maxItems = 30

    static func items(from text: String) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), OnDevice.isAvailable, text.count < modelLimit,
           let made = try? await Model.items(from: text) {
            let kept = keep(made, from: text)
            if !kept.isEmpty { return kept }
        }
        #endif
        return Checklist.split(text)
    }

    /// Only items in the text's own words, once each, thirty at most.
    static func keep(_ items: [String], from text: String) -> [String] {
        var seen = Set<String>()
        return items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && ModelGuard.sharesWords($0, with: text) }
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(maxItems)
            .map { $0 }
    }

    #if canImport(FoundationModels)
    // Not private: @Generable expands into an extension at file scope, which
    // has to see the type.
    @available(iOS 26, *)
    enum Model {
        @Generable
        struct List {
            @Guide(description: "The tasks or things in the text, one item each, short, in the order written, in the writer's own words. No new tasks, no advice, no headings.")
            var items: [String]
        }

        static func items(from text: String) async throws -> [String] {
            let session = LanguageModelSession(instructions: """
                You turn a note into a checklist: one item per task or thing, short, in the \
                order written, in the writer's own words and language. Add no tasks, advice, \
                or headings. Do not repeat an item.

                Example: milk eggs and call the dentist tuesday
                Items: milk; eggs; call the dentist tuesday

                Example: Before the trip: renew passport, book the cat sitter and pack the \
                charger. Also tell Sam.
                Items: renew passport; book the cat sitter; pack the charger; tell Sam
                """)
            let response = try await session.respond(to: text, generating: List.self, options: OnDevice.Model.options)
            return response.content.items
        }
    }
    #endif
}
