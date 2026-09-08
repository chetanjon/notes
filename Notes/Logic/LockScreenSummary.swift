import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The line under the title on the Lock Screen card, for a long plain
/// note: what the note is about, in a dozen words, from Apple's on-device
/// model (iOS 26 with Apple Intelligence). The note's first line stands in
/// until the model answers, and everywhere there is no model. Answers are
/// kept by text, so a note is summarised once, not on every foreground.
/// App only.
enum LockScreenSummary {
    static let limit = 6000
    static let wordLimit = 12
    private static let cacheSize = 16

    /// Text to summary, most recent last.
    private static var cache: [(text: String, line: String)] = []

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        return OnDevice.isAvailable
        #else
        return false
        #endif
    }

    static func line(for text: String) async -> String? {
        if let hit = cache.first(where: { $0.text == text }) { return hit.line }
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.line(for: text) {
            let line = made.split(separator: "\n").first.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? ""
            // Over the word limit, the model ran on; the first line stays.
            guard !line.isEmpty, ModelGuard.wordCount(line) <= wordLimit + 2 else { return nil }
            cache.append((text, line))
            if cache.count > cacheSize { cache.removeFirst() }
            return line
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    // Not private: @Generable expands into an extension at file scope.
    @available(iOS 26, *)
    enum Model {
        @Generable
        struct Line {
            @Guide(description: "One line, at most twelve words, saying what the note is about, in the writer's language, no full stop.")
            var line: String
        }

        static func line(for text: String) async throws -> String {
            let session = LanguageModelSession(instructions: """
                You write one line of at most twelve words saying what a note is about, in the \
                language it is written in, with no full stop. It sits under the note's title on \
                a Lock Screen, so it must stand on its own and name the concrete thing.

                Example note:
                Trip
                Flights booked for the 14th, hotel near the station, cat sitter confirmed, \
                still need travel insurance and to tell work.
                Line: Flights and hotel done, insurance and work still to do

                Example note:
                Walking app
                Record voice while walking, screen off, one button, turn it into text at home.
                Line: One-button voice recorder for walks that becomes text
                """)
            let response = try await session.respond(to: text, generating: Line.self,
                                                     options: OnDevice.Model.options)
            return response.content.line
        }
    }
    #endif
}
