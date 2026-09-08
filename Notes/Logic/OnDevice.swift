import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model, on an iPhone with Apple Intelligence (iOS 26),
/// behind the sparkle menu: "Add a title" and "Tidy up". Where there is no
/// model, `isAvailable` is false, the sparkle is only "Make a list", and
/// nothing here runs. The text never leaves the phone. App only.
enum OnDevice {
    /// The model's context is small; past this the sparkle does nothing.
    static let limit = 6000

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            return true
        }
        #endif
        return false
    }

    /// A title for the note: a few words in the writer's language, on one
    /// line, with no full stop. Nil when the model has nothing to give.
    static func title(for text: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.title(for: text) {
            let title = made
                .split(separator: "\n").first.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’."))
                .trimmingCharacters(in: .whitespaces) ?? ""
            if !title.isEmpty { return title }
        }
        #endif
        return nil
    }

    /// The lines with spelling, capitalisation and punctuation fixed, one
    /// out for each one in, or nil: when there is no model, when it gave a
    /// different number of lines, or when it changed nothing.
    static func tidied(_ lines: [String]) async -> [String]? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, lines.joined(separator: "\n").count < limit,
           let made = try? await Model.tidied(lines), made.count == lines.count {
            let trimmed = made.map { $0.trimmingCharacters(in: .whitespaces) }
            if trimmed != lines.map({ $0.trimmingCharacters(in: .whitespaces) }) { return trimmed }
        }
        #endif
        return nil
    }

    /// The items grouped by kind, as a new order: each item's index exactly
    /// once, first for the top. Nil when there is no model, when it gave
    /// anything but a permutation, or when it changed nothing.
    static func sorted(_ items: [String]) async -> [Int]? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, items.count >= 3,
           items.joined(separator: "\n").count < limit,
           let made = try? await Model.sorted(items) {
            let order = made.map { $0 - 1 }
            if order.count == items.count, Set(order) == Set(items.indices),
               order != Array(items.indices) { return order }
        }
        #endif
        return nil
    }

    /// The things in the note that have a day or a time: each as a short
    /// title and when it is due. Empty when the note has none; nil when
    /// there is no model.
    static func reminders(in text: String, now: Date = .now) async -> [Reminders.Found]? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.reminders(in: text, today: ReminderStamp.today(now)) {
            return made.compactMap { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, let due = ReminderStamp.parse(item.when) else { return nil }
                return Reminders.Found(title: title, due: due)
            }
        }
        #endif
        return nil
    }

    /// A dictation as a note: a title, the words with spelling and
    /// punctuation fixed and filler dropped, each spoken task or item on a
    /// line of its own as a checklist item. Nil where there is no model or
    /// it gave nothing.
    static func cleaned(dictation: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, dictation.count < limit,
           let made = try? await Model.cleaned(dictation: dictation) {
            let text = Dictation.compose(title: made.title, lines: made.lines)
            if !NoteText.isBlank(text) { return text }
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    // Not private: @Generable expands into an extension at file scope, which
    // has to see the type.
    @available(iOS 26, *)
    enum Model {
        @Generable
        struct Title {
            @Guide(description: "A title for the note: two to five words, in the writer's language, no full stop, not a copy of the first line.")
            var title: String
        }

        @Generable
        struct Tidy {
            @Guide(description: "The same lines, in the same order, one for one, with spelling, capitalisation and punctuation fixed and nothing else changed. An empty line stays empty.")
            var lines: [String]
        }

        static func title(for text: String) async throws -> String {
            let session = LanguageModelSession(instructions: """
                The user gives you a note. Reply with a title for it: two to five words, in the \
                language the note is written in, no full stop at the end. Say what the note is \
                about; do not copy its first line.
                """)
            let response = try await session.respond(to: text, generating: Title.self)
            return response.content.title
        }

        @Generable
        struct Order {
            @Guide(description: "Every item's number exactly once, in the new order: items of the same kind next to each other, such as things bought in the same aisle, done in the same place, or belonging together.")
            var order: [Int]
        }

        static func sorted(_ items: [String]) async throws -> [Int] {
            let listing = items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                The user gives you a numbered checklist. Give back the numbers in a new order \
                that puts items of the same kind next to each other: things from the same shop \
                aisle, errands in the same place, tasks that belong together. Use every number \
                exactly once and add none.
                """)
            let response = try await session.respond(to: listing, generating: Order.self)
            return response.content.order
        }

        @Generable
        struct Dated {
            @Guide(description: "A few words saying what is to be done, in the writer's own words.")
            var title: String
            @Guide(description: "When it is due, as YYYY-MM-DD, or YYYY-MM-DDTHH:MM in 24-hour time when the note gives a time. Empty when the note gives no day.")
            var when: String
        }

        @Generable
        struct DatedList {
            @Guide(description: "Every thing in the note that has a day or a time. Empty when there is none.")
            var items: [Dated]
        }

        static func reminders(in text: String, today: String) async throws -> [Dated] {
            let session = LanguageModelSession(instructions: """
                Today is \(today). The user gives you a note. Find every thing in it that has a \
                day or a time ("dentist tuesday 3pm", "rent on the 1st", "call mum tomorrow") and \
                give each as a short title and its date, YYYY-MM-DD, with THH:MM in 24-hour time \
                when a time is given. A weekday means the next such day, today included. Leave \
                out anything with no day.
                """)
            let response = try await session.respond(to: text, generating: DatedList.self)
            return response.content.items
        }

        @Generable
        struct Spoken {
            @Guide(description: "A title for the note: two to five words, in the speaker's language, no full stop.")
            var title: String
            @Guide(description: "The note's lines, in the speaker's own words with spelling and punctuation fixed and filler words dropped. When the speech is a list of tasks or things, each on its own line starting with '- '.")
            var lines: [String]
        }

        static func cleaned(dictation: String) async throws -> Spoken {
            let session = LanguageModelSession(instructions: """
                The user dictated a note; you get the words as heard. Give it a title of two to \
                five words and write the note as lines in the speaker's own words, with spelling \
                and punctuation fixed and filler words ("um", "so", "like") dropped. Do not add \
                anything that was not said. When the speech is a list of tasks or things to buy, \
                put each on its own line starting with "- ".
                """)
            let response = try await session.respond(to: dictation, generating: Spoken.self)
            return response.content
        }

        static func tidied(_ lines: [String]) async throws -> [String] {
            let session = LanguageModelSession(instructions: """
                The user gives you the lines of a note. Fix spelling, capitalisation and \
                punctuation in each line and change nothing else: not the words, not the \
                meaning, not the order. Give back exactly one line for each line you were \
                given, in the same order. An empty line stays empty.
                """)
            let response = try await session.respond(to: lines.joined(separator: "\n"), generating: Tidy.self)
            return response.content.lines
        }
    }
    #endif
}
