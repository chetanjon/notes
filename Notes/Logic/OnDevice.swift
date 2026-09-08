import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model, on an iPhone with Apple Intelligence (iOS 26),
/// behind the sparkle menu and the pencil. Where there is no model,
/// `isAvailable` is false, the sparkle is only "Make a list", and nothing
/// here runs. The text never leaves the phone. App only.
///
/// How the model is driven, the same way for every task: an instruction
/// with two worked examples (this is a small model; examples do more than
/// rules), greedy sampling so the same note gives the same answer, output
/// shaped by `@Generable` and `@Guide`, one prewarmed session per launch so
/// the first tap is not the slow one, and a check on what comes back
/// (`ModelGuard`) so only what the model got right is applied.
enum OnDevice {
    /// The model's context is small; past this the sparkle does nothing.
    static let limit = 6000

    enum Status: Equatable {
        case ready
        /// Apple Intelligence is turned off in Settings.
        case off
        /// The model is still downloading.
        case downloading
        /// No model on this phone.
        case none
    }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .ready
            case .unavailable(.appleIntelligenceNotEnabled): return .off
            case .unavailable(.modelNotReady): return .downloading
            default: return .none
            }
        }
        #endif
        return .none
    }

    static var isAvailable: Bool { status == .ready }

    /// Loads the model once per launch, so the first tap answers as fast as
    /// the second. Cheap to call again.
    static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable { Model.prewarm() }
        #endif
    }

    /// A title for the note: a few words in the writer's language, on one
    /// line, with no full stop. Nil when the model has nothing to give, or
    /// gave the first line back, or ran on.
    static func title(for text: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.title(for: text) {
            let title = made
                .split(separator: "\n").first.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’.:"))
                .trimmingCharacters(in: .whitespaces) ?? ""
            let first = NoteText.title(text)
            if !title.isEmpty, ModelGuard.wordCount(title) <= 8,
               title.compare(first, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame {
                return title
            }
        }
        #endif
        return nil
    }

    /// The lines with spelling, capitalisation and punctuation fixed, one
    /// out for each one in. A line the model did not give back, gave twice,
    /// or rewrote (its length changed by more than 40%) keeps its original;
    /// so a mostly right answer still applies. Nil when there is no model
    /// or nothing changed.
    static func tidied(_ lines: [String]) async -> [String]? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, lines.joined(separator: "\n").count < limit,
           let made = try? await Model.tidied(lines) {
            var result = lines.map { $0.trimmingCharacters(in: .whitespaces) }
            var seen = Set<Int>()
            for fix in made where fix.number >= 1 && fix.number <= lines.count && seen.insert(fix.number).inserted {
                let was = lines[fix.number - 1].trimmingCharacters(in: .whitespaces)
                let now = fix.text.trimmingCharacters(in: .whitespaces)
                if was.isEmpty != now.isEmpty { continue }
                if ModelGuard.lengthClose(was, now) { result[fix.number - 1] = now }
            }
            // Capitals are a rule, not a judgement: the first letter of each
            // line and the pronoun "I", whatever the model did with them.
            result = result.map(NoteText.capitalised)
            if result != lines.map({ $0.trimmingCharacters(in: .whitespaces) }) { return result }
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
    /// there is no model. A title made of words not in the note is dropped.
    static func reminders(in text: String, now: Date = .now) async -> [Reminders.Found]? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.reminders(in: text, week: ReminderStamp.week(from: now)) {
            return made.compactMap { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty, ModelGuard.sharesWords(title, with: text),
                      let due = ReminderStamp.parse(item.when) else { return nil }
                return Reminders.Found(title: title, due: due)
            }
        }
        #endif
        return nil
    }

    /// A dictation as a note: a title, the words with spelling and
    /// punctuation fixed and filler dropped, each spoken task or item on a
    /// line of its own as a checklist item. Nil where there is no model, it
    /// gave nothing, or it kept less than half of what was said.
    static func cleaned(dictation: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, dictation.count < limit,
           let made = try? await Model.cleaned(dictation: dictation) {
            let body = made.lines.joined(separator: "\n")
            guard ModelGuard.kept(of: dictation, in: made.title + "\n" + body) >= 0.5 else { return nil }
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
        /// Greedy: the same note gives the same answer, and the model keeps
        /// to what it was given rather than inventing.
        static let options = GenerationOptions(sampling: .greedy)

        private static var warmed = false

        static func prewarm() {
            guard !warmed else { return }
            warmed = true
            LanguageModelSession().prewarm()
        }

        // MARK: Title

        @Generable
        struct Title {
            @Guide(description: "Two to five words in the language of the note, no full stop, not the first line copied.")
            var title: String
        }

        static func title(for text: String) async throws -> String {
            let session = LanguageModelSession(instructions: """
                You give a note a title: two to five words, in the language the note is written \
                in, no full stop at the end. Say what the note is about. Never copy the first line.

                Example note:
                milk eggs bread
                call the dentist tuesday
                Title: Errands this week

                Example note:
                The walk app should record voice notes while walking and turn them into text \
                at home. Keep the screen off. One button.
                Title: Walking app idea
                """)
            let response = try await session.respond(to: text, generating: Title.self, options: options)
            return response.content.title
        }

        // MARK: Tidy

        @Generable
        struct Fixed {
            @Guide(description: "The line's number, as given.")
            var number: Int
            @Guide(description: "That line with spelling, capitalisation and punctuation fixed and nothing else changed. Empty when the line was empty.")
            var text: String
        }

        @Generable
        struct Fixes {
            @Guide(description: "One entry for every numbered line, in order.")
            var lines: [Fixed]
        }

        static func tidied(_ lines: [String]) async throws -> [Fixed] {
            let numbered = lines.enumerated().map { "\($0.offset + 1)| \($0.element)" }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                You fix the lines of a note. Each line comes as its number, a bar, and the text. \
                Fix spelling, capitalisation and punctuation in each line and change nothing \
                else: not the words, not the meaning, not the order, not the length. Every \
                line starts with a capital letter, and the pronoun "i" is always "I". Give \
                back every line by number. An empty line stays empty.

                Example:
                1| call teh dentist tuesday
                2|
                3| i recieved the parcel , its fine
                Gives:
                1: Call the dentist Tuesday
                2:
                3: I received the parcel, it's fine

                Example:
                1| Groceries
                2| milk eggs bread
                Gives:
                1: Groceries
                2: Milk, eggs, bread
                """)
            let response = try await session.respond(to: numbered, generating: Fixes.self, options: options)
            return response.content.lines
        }

        // MARK: Sort

        @Generable
        struct Order {
            @Guide(description: "Every item's number exactly once, in the new order: items of the same kind next to each other.")
            var order: [Int]
        }

        static func sorted(_ items: [String]) async throws -> [Int] {
            let listing = items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                You reorder a numbered checklist so items of the same kind sit next to each \
                other: things from the same shop aisle, errands in the same place, tasks that \
                belong together. Give back the numbers in the new order, every number exactly \
                once, none added.

                Example:
                1. milk
                2. batteries
                3. cheese
                4. light bulb
                5. yoghurt
                Gives: 1, 3, 5, 2, 4

                Example:
                1. book flights
                2. call mum
                3. pack charger
                4. text dad
                Gives: 1, 3, 2, 4
                """)
            let response = try await session.respond(to: listing, generating: Order.self, options: options)
            return response.content.order
        }

        // MARK: Reminders

        @Generable
        struct Dated {
            @Guide(description: "A few words saying what is to be done, in the note's own words.")
            var title: String
            @Guide(description: "When it is due: YYYY-MM-DD, or YYYY-MM-DDTHH:MM in 24-hour time when the note gives a time. Empty when the note gives no day.",
                   .pattern(/^(\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?)?$/))
            var when: String
        }

        @Generable
        struct DatedList {
            @Guide(description: "Every thing in the note that has a day or a time. Empty when there is none.")
            var items: [Dated]
        }

        static func reminders(in text: String, week: String) async throws -> [Dated] {
            let session = LanguageModelSession(instructions: """
                You find the things in a note that have a day or a time, and give each as a \
                short title in the note's own words and its date. Use this calendar for the \
                coming week; a weekday in the note means the day listed here:
                \(week)
                Dates are YYYY-MM-DD, with THH:MM in 24-hour time when the note gives a time \
                (3pm is T15:00, 9 is T09:00). "Tomorrow" and "tonight" are on the calendar \
                above. Leave out anything with no day.

                Example note (with the calendar's Tuesday being 2026-09-08):
                dentist tuesday 3pm
                buy milk
                rent due on the 1st
                Gives:
                - Dentist, 2026-09-08T15:00
                - Rent due, 2026-10-01

                Example note (with the calendar's tomorrow being 2026-09-09):
                call mum tomorrow morning
                gym
                Gives:
                - Call mum, 2026-09-09T09:00
                """)
            let response = try await session.respond(to: text, generating: DatedList.self, options: options)
            return response.content.items
        }

        // MARK: Dictation

        @Generable
        struct Spoken {
            @Guide(description: "Two to five words in the speaker's language, no full stop.")
            var title: String
            @Guide(description: "The note's lines in the speaker's own words, spelling and punctuation fixed, filler words dropped. A list of tasks or things: each on its own line starting with '- '.")
            var lines: [String]
        }

        static func cleaned(dictation: String) async throws -> Spoken {
            let session = LanguageModelSession(instructions: """
                You turn a dictated note, as heard, into a written note: a title of two to \
                five words, then the note as lines in the speaker's own words with spelling \
                and punctuation fixed and filler ("um", "so", "like", "you know") dropped. Add \
                nothing that was not said. When the speech is a list of tasks or things to buy, \
                put each on its own line starting with "- ".

                Example heard: um so for the shop I need milk eggs and uh bread and also call \
                the dentist tuesday
                Title: Shop and dentist
                Lines:
                - Milk
                - Eggs
                - Bread
                - Call the dentist Tuesday

                Example heard: idea for the walking app like it should just record voice while \
                you walk and then you know make it text later
                Title: Walking app idea
                Lines:
                Record voice while you walk, then make it text later.
                """)
            let response = try await session.respond(to: dictation, generating: Spoken.self, options: options)
            return response.content
        }
    }
    #endif
}
