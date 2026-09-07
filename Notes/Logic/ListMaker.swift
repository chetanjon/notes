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

    static func items(from text: String) async -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), text.count < modelLimit,
           case .available = SystemLanguageModel.default.availability,
           let made = try? await Model.items(from: text), !made.isEmpty {
            return made
        }
        #endif
        return Checklist.split(text)
    }

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private enum Model {
        @Generable
        struct List {
            @Guide(description: "The tasks or things in the text, one item each, short, in the order written, in the writer's own words. No new tasks, no advice, no headings.")
            var items: [String]
        }

        static func items(from text: String) async throws -> [String] {
            let session = LanguageModelSession(instructions: """
                The user gives you a note. Turn it into a checklist: one item per task or thing, \
                short, in the order written, keeping the user's own words. Do not add tasks, \
                advice, or headings.
                """)
            let response = try await session.respond(to: text, generating: List.self)
            return response.content.items
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
    #endif
}
