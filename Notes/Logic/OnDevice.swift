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

    /// The lines tidied, one out for each one in: the model makes each read
    /// cleanly where there is one, and every line then gets the careful
    /// typist's pass (`NoteText.tidied`), model or not. A line the model
    /// did not give back, gave twice, rewrote, or ran together with another
    /// keeps its original (`ModelGuard.tidyKeeps`), so a mostly right
    /// answer still applies and lines are never merged. An item keeps its
    /// fragment form: no full stop on "Milk". Nil when nothing changed.
    static func tidied(_ lines: [String], items: [Bool] = []) async -> [String]? {
        let original = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        var result = original
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, lines.joined(separator: "\n").count < limit,
           let made = try? await Model.tidied(lines) {
            var seen = Set<Int>()
            for fix in made where fix.number >= 1 && fix.number <= lines.count && seen.insert(fix.number).inserted {
                let index = fix.number - 1
                let others = original.indices.filter { $0 != index }.map { original[$0] }
                if ModelGuard.tidyKeeps(original[index], fix.text, others: others) {
                    result[index] = fix.text.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        #endif
        result = result.enumerated().map { index, line in
            var tidy = NoteText.tidied(line)
            if index < items.count, items[index], tidy.hasSuffix("."), !tidy.hasSuffix("..") { tidy.removeLast() }
            return tidy
        }
        return result != original ? result : nil
    }

    /// The items grouped by kind, as a new order: each item's index exactly
    /// once, first for the top. The model labels each item with its kind
    /// and `ListSorter` turns the labels into the order. Nil when there is
    /// no model, when a label is missing, or when nothing would move.
    /// What "Sort the list" came back with, so the editor can tell the two
    /// apart: the list was already grouped, or the model had nothing usable
    /// to say. Both used to read as "Already in order".
    enum Sorted: Equatable {
        case order([Int])
        case alreadyGrouped
        case noAnswer
    }

    static func sorted(_ items: [String]) async -> Sorted {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, items.count >= 3,
           items.joined(separator: "\n").count < limit {
            guard let made = try? await Model.grouped(items), !made.isEmpty else { return .noAnswer }
            switch ListSorter.outcome(groups: made.map { (number: $0.number, group: $0.group) },
                                      count: items.count) {
            case let .order(order): return .order(order)
            case .alreadyGrouped: return .alreadyGrouped
            case .noAnswer: return .noAnswer
            }
        }
        #endif
        return .noAnswer
    }

    /// The things in the note that have a day or a time: each as a short
    /// title and when it is due. Empty when the note has none; nil when
    /// there is no model. A title made of words not in the note is dropped.
    static func reminders(in text: String, now: Date = .now) async -> [Reminders.Found]? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.reminders(in: DateSpotter.segments(of: text).joined(separator: "\n"),
                                                 week: ReminderStamp.week(from: now)) {
            return made.compactMap { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                // A title of only small words ("do it", "TBD") passes the
                // strict check, whose word set is empty; it makes a useless
                // reminder and a notification nothing can ever cancel.
                guard !title.isEmpty, ModelGuard.grounded(title, in: text),
                      let due = ReminderStamp.parse(item.when) else { return nil }
                return Reminders.Found(title: title, due: due)
            }
        }
        #endif
        return nil
    }

    /// Briefs already written, by text: the same note gives the same brief
    /// without a second call. Behind a lock, since `brief(for:)` runs on
    /// whatever thread its task lands on.
    private static var briefs: [(text: String, brief: Brief)] = []
    private static let briefLock = NSLock()

    /// "Where did I leave off?": what the note has settled, what is still
    /// open, and what to do next, in the note's own words. Nil when there
    /// is no model or it found nothing to say.
    static func brief(for text: String) async -> Brief? {
        if let hit = briefLock.withLock({ briefs.first(where: { $0.text == text }) }) { return hit.brief }
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, text.count < limit,
           let made = try? await Model.brief(for: text),
           let brief = Brief.kept(decided: made.decided, open: made.open, next: made.next, from: text) {
            briefLock.withLock {
                briefs.append((text, brief))
                if briefs.count > 16 { briefs.removeFirst() }
            }
            return brief
        }
        #endif
        return nil
    }

    /// "You've thought about this before": which of the candidate notes
    /// bears on what is being written, and the line of it that says so
    /// (`Recall.quote`, so the hint is always a line the note contains).
    /// Nil when none does, or there is no model.
    static func recall(writing: String, candidates: [NoteFinder.Card]) async -> (id: UUID, said: String)? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable, !candidates.isEmpty, writing.count < limit,
           let made = try? await Model.recall(writing: writing, candidates: candidates),
           made.note >= 1, made.note <= candidates.count {
            let card = candidates[made.note - 1]
            let said = made.said.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            if !said.isEmpty, ModelGuard.wordCount(said) <= 20, ModelGuard.sharesWords(said, with: card.text),
               let quote = Recall.quote(from: card.text, near: said) {
                return (card.id, quote)
            }
        }
        #endif
        return nil
    }

    /// A dictation as a note: a title, the words with spelling and
    /// punctuation fixed and filler dropped, each spoken task or item on a
    /// line of its own as a checklist item. Nil where there is no model, it
    /// gave nothing, or it kept less than half of what was said.
    /// Answers why, not just nil. Every way this can fail used to look the
    /// same to the caller, so a note that came back untidied never said
    /// whether the model was missing, busy, or simply not believed.
    static func cleaned(dictation: String) async -> Dictation.Cleaning {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            guard isAvailable else { return .noModel }
            guard dictation.count < limit else { return .tooLong }
            guard let made = try? await Model.cleaned(dictation: dictation) else { return .notTrusted }
            let lines = made.lines.map { $0.isItem ? "- " + $0.text : $0.text }
            let body = made.lines.map(\.text).joined(separator: "\n")
            // The model was told to drop "um", "like", "you know"; counting
            // those as words lost means the more filler is spoken, the more
            // certain a good cleanup is thrown away.
            guard ModelGuard.kept(of: Dictation.withoutFiller(dictation),
                                  in: made.title + "\n" + body) >= 0.5 else { return .notTrusted }
            let text = Dictation.compose(title: made.title, lines: lines)
            guard !NoteText.isBlank(text) else { return .notTrusted }
            return .cleaned(text)
        }
        #endif
        return .noModel
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
                You tidy the lines of a note so each reads cleanly. Each line comes as its \
                number, a bar, and the text. Fix spelling, capitals, spacing and punctuation: \
                commas where a reader needs a breath, apostrophes ("its fine" is "it's fine"), \
                and a full stop on a sentence. Drop filler like "um" and "basically". Keep the \
                writer's own words, order and meaning; add nothing. A short list line such as \
                "milk eggs bread" stays a fragment with no full stop. Give back one line for \
                every line, by number: never join two lines, never split one, and an empty \
                line stays empty.

                Example:
                1| This week
                2| call teh dentist tuesday its at 3 i think
                3|
                4| i recieved the parcel , its fine
                Gives:
                1: This week
                2: Call the dentist Tuesday, it's at 3, I think.
                3:
                4: I received the parcel, it's fine.

                Example:
                1| Groceries
                2| milk eggs bread
                3| um also batteries for the remote
                Gives:
                1: Groceries
                2: Milk, eggs, bread
                3: Batteries for the remote
                """)
            let response = try await session.respond(to: numbered, generating: Fixes.self, options: options)
            return response.content.lines
        }

        // MARK: Sort

        @Generable
        struct Labelled {
            @Guide(description: "The item's number.")
            var number: Int
            @Guide(description: "The kind of thing it is, one or two words: dairy, hardware, calls, packing, fruit.")
            var group: String
        }

        @Generable
        struct Groups {
            @Guide(description: "One entry for every item, in the list's own order.")
            var items: [Labelled]
        }

        static func grouped(_ items: [String]) async throws -> [Labelled] {
            let listing = items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                You label each item of a numbered checklist with the kind of thing it is, so \
                items of the same kind can be put together: the same shop aisle, errands in \
                the same place, tasks that belong together. Use the same label for items of \
                the same kind. One entry for every item, by number.

                Example:
                1. milk
                2. batteries
                3. cheese
                4. light bulb
                5. yoghurt
                Gives: 1 dairy, 2 hardware, 3 dairy, 4 hardware, 5 dairy

                Example:
                1. book flights
                2. call mum
                3. pack charger
                4. text dad
                Gives: 1 travel, 2 calls, 3 travel, 4 calls
                """)
            let response = try await session.respond(to: listing, generating: Groups.self, options: options)
            return response.content.items
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

        // MARK: Where did I leave off

        @Generable
        struct Standing {
            @Guide(description: "What the note has settled, each a few words in the note's own words.", .maximumCount(3))
            var decided: [String]
            @Guide(description: "What is still undecided or not done, each a few words in the note's own words.", .maximumCount(3))
            var open: [String]
            @Guide(description: "The one next step the note points to, a few words, or empty.")
            var next: String
        }

        static func brief(for text: String) async throws -> Standing {
            let session = LanguageModelSession(instructions: """
                The user is coming back to a note after a while. Say where it stands, in the \
                note's own words: what has been decided, what is still open, and the next \
                step. Only what the note says; nothing added. Empty lists are fine.

                Example note:
                Japan trip
                October, two weeks. Budget $3,000.
                Hotels: one near the station, one by the park. Not decided.
                Need to compare prices this weekend.
                Gives: decided October, two weeks; $3,000 budget. open which hotel. next \
                compare prices this weekend.

                Example note:
                Walking app
                Record voice while walking, screen off, one button.
                Transcribe at home, not live. Name still open: Stride or Amble.
                Gives: decided record voice while walking; transcribe at home. open the name, \
                Stride or Amble. next (empty).
                """)
            let response = try await session.respond(to: text, generating: Standing.self, options: options)
            return response.content
        }

        // MARK: You've thought about this before

        @Generable
        struct Recalled {
            @Guide(description: "The number of the older note that bears on what is being written, or 0 when none does.")
            var note: Int
            @Guide(description: "What that older note said about it, in its own words, under twenty words. Empty when note is 0.")
            var said: String
        }

        static func recall(writing: String, candidates: [NoteFinder.Card]) async throws -> Recalled {
            let listing = candidates.enumerated()
                .map { "\($0.offset + 1). \(NoteText.oneLine($0.element.text, limit: NoteFinder.cardLimit))" }
                .joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                The user is writing a note. You get what they are writing and a numbered list \
                of their older notes. If one of the older notes says something they should \
                remember about the same thing, give its number and what it said, in its own \
                words. If none does, give 0. Do not stretch: the same topic is not enough; it \
                must say something that bears on what is being written.

                Example writing: Thinking about getting a standing desk for the study.
                Older notes:
                1. Shop: milk, eggs, bread
                2. Standing desk: tried standing all day at work, knee hurt for a week, back to sitting
                Gives: note 2; said "standing all day hurt my knee for a week"

                Example writing: Book ideas: a novel set in a lighthouse.
                Older notes:
                1. Reading list: The Lighthouse by Woolf, Dune
                2. Trip: Cornwall in May, see the lighthouse at Lizard Point
                Gives: note 0; said empty
                """)
            let response = try await session.respond(
                to: "Writing: \(writing)\n\nOlder notes:\n\(listing)", generating: Recalled.self, options: options)
            return response.content
        }

        // MARK: Dictation

        @Generable
        struct SpokenLine {
            @Guide(description: "The line, in the speaker's own words, spelling and punctuation fixed, filler dropped.")
            var text: String
            @Guide(description: "True when the line is one task or one thing on a list; false for a sentence.")
            var isItem: Bool
        }

        @Generable
        struct Spoken {
            @Guide(description: "Two to five words in the speaker's language, no full stop.")
            var title: String
            @Guide(description: "The note's lines, one per task or thing when the speech is a list, one per sentence otherwise.")
            var lines: [SpokenLine]
        }

        static func cleaned(dictation: String) async throws -> Spoken {
            let session = LanguageModelSession(instructions: """
                You turn a dictated note, as heard, into a written note: a title of two to \
                five words, then the note as lines in the speaker's own words with spelling \
                and punctuation fixed and filler ("um", "so", "like", "you know") dropped. Add \
                nothing that was not said. When the speech is a list of tasks or things to buy, \
                each goes on its own line as an item (isItem true); a sentence is a line that \
                is not an item.

                Example heard: um so for the shop I need milk eggs and uh bread and also call \
                the dentist tuesday
                Title: Shop and dentist
                Lines: Milk (item), Eggs (item), Bread (item), Call the dentist Tuesday (item)

                Example heard: idea for the walking app like it should just record voice while \
                you walk and then you know make it text later
                Title: Walking app idea
                Lines: Record voice while you walk, then make it text later. (not an item)
                """)
            let response = try await session.respond(to: dictation, generating: Spoken.self, options: options)
            return response.content
        }
    }
    #endif
}
