import Foundation

/// Checks on what the on-device model gives back, so only what it got
/// right is applied. Pure, so they are tested without the model.
///
/// Two kinds of writing pass through here. Scripts with spaces between
/// words — English, Korean, most of the world — are split into words and
/// judged by word overlap, as they always were. Scripts without them —
/// Chinese, Japanese, Thai and their neighbours — used to arrive as one
/// "word" per line, so the first comma the model added split that word in
/// two and every guard read a faithful cleanup as a total rewrite: the
/// model features were silently off for whole languages. A dense run is
/// now taken as its overlapping character pairs instead. Pairs are not
/// words, but overlap is what these guards measure, not linguistics, and
/// pairs are deterministic on every platform where a dictionary
/// segmenter is not.
enum ModelGuard {
    /// Words that say nothing about what a note is about.
    static let stopWords: Set<String> = [
        "the", "and", "for", "with", "when", "what", "where", "which", "who", "how",
        "this", "that", "these", "those", "was", "were", "are", "is", "not", "you",
        "your", "our", "its", "from", "into", "about", "then", "than", "but", "have",
        "has", "had", "did", "does", "will", "can", "could", "should", "would",
    ]

    /// The scripts written without spaces between words: Thai, Lao,
    /// Tibetan, Myanmar, Khmer, Tai Lue, and the Han and kana blocks.
    /// Hangul is deliberately absent: Korean writes with spaces and goes
    /// down the word path it always did.
    private static let spacelessRanges: [ClosedRange<UInt32>] = [
        0x0E00...0x0E7F, 0x0E80...0x0EFF, 0x0F00...0x0FFF, 0x1000...0x109F,
        0x1780...0x17FF, 0x19E0...0x19FF, 0x2E80...0x2EFF, 0x3005...0x3007,
        0x3040...0x30FF, 0x31C0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF,
        0xF900...0xFAFF, 0xFF66...0xFF9D, 0x20000...0x3FFFF,
    ]

    /// The days and months that are never an ordinary English word.
    /// "may", "march" and "august" are left out on purpose, and so is every
    /// three-letter abbreviation: refusing "may need a hotel" for naming a
    /// month would be a worse guard than the hole it closed. What is left
    /// is pinned in `testTheKnownHolesStayKnown`.
    private static let dayWords: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "april", "june", "july", "september", "october",
        "november", "december",
    ]

    /// A weekday written in Han is taken whole, so that the 三 inside
    /// 周三 is the day and not a number standing on its own.
    private static let weekPrefixes = ["星期", "礼拜", "禮拜", "周", "週"]
    private static let weekDays: Set<Character> = [
        "一", "二", "三", "四", "五", "六", "日", "天",
    ]
    private static let japaneseWeekDays: Set<Character> = [
        "月", "火", "水", "木", "金", "土", "日",
    ]

    static func isSpaceless(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return spacelessRanges.contains { $0.contains(scalar.value) }
    }

    static func hasSpaceless(_ text: String) -> Bool { text.contains(where: isSpaceless) }

    /// The tokens that carry meaning. For spaced scripts: whole words,
    /// three letters or more — or any length at all if there is a number
    /// in them — lowercased, accents dropped, the stop words left out.
    /// For a run of a spaceless script: its overlapping
    /// character pairs — and a run of a single character is that
    /// character, because an empty set passes the subset check by being
    /// empty, and 米 on a shopping list is an ordinary item, not noise.
    static func words(_ text: String) -> Set<String> {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var found: Set<String> = []
        for run in folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            var spaced: [Character] = []
            var dense: [Character] = []
            func takeSpaced() {
                guard !spaced.isEmpty else { return }
                let word = String(spaced)
                spaced.removeAll(keepingCapacity: true)
                // The floor is about letters: "at" and "to" say nothing.
                // A number always says something, however short.
                let carries = word.count >= 3 || word.contains(where: \.isNumber)
                if carries, !stopWords.contains(word) { found.insert(word) }
            }
            func takeDense() {
                if dense.count == 1 {
                    found.insert(String(dense[0]))
                } else if dense.count >= 2 {
                    for i in 0..<(dense.count - 1) { found.insert(String(dense[i...(i + 1)])) }
                }
                dense.removeAll(keepingCapacity: true)
            }
            for character in run {
                if isSpaceless(character) {
                    takeSpaced()
                    dense.append(character)
                } else {
                    takeDense()
                    spaced.append(character)
                }
            }
            takeSpaced()
            takeDense()
        }
        return found
    }

    /// The numbers and days a line says, as themselves rather than as
    /// tokens: runs of digits, runs of Han numerals, the weekdays written
    /// in Han, and the day and month words of English. Neither path in
    /// `words` can carry these. The three-letter floor drops "16" before
    /// any guard sees it, and 周二下午三点看牙医 becomes eight character
    /// pairs, of which changing the day alters two — which is exactly the
    /// quarter a 0.75 ratio is willing to spare.
    static func figures(_ text: String) -> Set<String> {
        let characters = Array(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
        var found: Set<String> = []
        var letters: [Character] = []
        var number: [Character] = []

        func takeLetters() {
            let word = String(letters)
            letters.removeAll(keepingCapacity: true)
            if dayWords.contains(word) { found.insert(word) }
        }
        func takeNumber() {
            // A thousands separator is the same amount written out, so it
            // comes off rather than splitting 3,500 into a 3 and a 500.
            let digits = String(number.filter(\.isNumber))
            number.removeAll(keepingCapacity: true)
            if !digits.isEmpty { found.insert(digits) }
        }
        func takeAll() { takeLetters(); takeNumber() }

        var index = 0
        while index < characters.count {
            if let day = weekday(at: index, in: characters) {
                takeAll()
                found.insert(day)
                index += day.count
                continue
            }
            let character = characters[index]
            // `isNumber` is asked before `isLetter` because Swift calls 三
            // both. It is true of every Han numeral, so 3500 and 三千 come
            // down one path and neither needs a table of its own. The cost
            // is that the 一 in 一起 ("together") reads as a one, which can
            // make a cleanup that adds such a word refused — never
            // accepted, so it errs the safe way.
            if character.isNumber {
                takeLetters()
                number.append(character)
            } else if character == "," || character == "，",
                      !number.isEmpty,
                      index + 1 < characters.count, characters[index + 1].isNumber {
                number.append(character)
            } else if character.isLetter {
                takeNumber()
                letters.append(character)
            } else {
                takeAll()
            }
            index += 1
        }
        takeAll()
        return found
    }

    /// 星期三, 周三, 礼拜三, 水曜日: the weekday starting here, or nothing.
    /// A trailing 日 is left off 水曜日 so that it and 水曜 are one day.
    private static func weekday(at index: Int, in characters: [Character]) -> String? {
        for prefix in weekPrefixes where index + prefix.count < characters.count {
            let day = index + prefix.count
            guard String(characters[index..<day]) == prefix, weekDays.contains(characters[day]) else { continue }
            return prefix + String(characters[day])
        }
        guard index + 1 < characters.count, characters[index + 1] == "曜",
              japaneseWeekDays.contains(characters[index]) else { return nil }
        return String(characters[index...(index + 1)])
    }

    /// Every number and day in `candidate` is one the source says. A figure
    /// is the same one or a different one and there is nothing in between,
    /// so no ratio spares it and no spelling allowance reaches it: 3800 is
    /// one edit from 3500 and a different amount all the same.
    static func inventsNoFigure(_ candidate: String, in source: String) -> Bool {
        figures(candidate).isSubset(of: figures(source))
    }

    /// A figure in the tidy that the line did not say, allowed only when
    /// the line has a word near it that is not a figure of its own:
    /// "tuesdy" becoming "Tuesday". Both halves of one real day becoming
    /// another are figures, so that never takes this path.
    private static func correcting(_ figure: String, of source: String) -> Bool {
        let said = figures(source)
        return words(source).contains { !said.contains($0) && near(figure, $0) }
    }

    /// A single character of a spaceless script, found inside one of the
    /// set's tokens. The pairs 买米 and 米和 both contain the item 米; no
    /// pair anywhere contains an invented 猫. A spaced word never takes
    /// this path, however short: the character has to be a spaceless one.
    private static func containsLone(_ word: String, in set: Set<String>) -> Bool {
        guard word.count == 1, let only = word.first, isSpaceless(only) else { return false }
        return set.contains { $0.contains(word) }
    }

    /// The candidate's words all occur in the source: nothing was invented.
    /// A candidate with no words of its own passes.
    static func sharesWords(_ candidate: String, with source: String) -> Bool {
        guard inventsNoFigure(candidate, in: source) else { return false }
        let theirs = words(source)
        return words(candidate).allSatisfy { theirs.contains($0) || containsLone($0, in: theirs) }
    }

    /// The share of the source's words that survive in the candidate.
    static func kept(of source: String, in candidate: String) -> Double {
        let from = words(source)
        guard !from.isEmpty else { return 1 }
        return Double(from.intersection(words(candidate)).count) / Double(from.count)
    }

    /// The same share, counting a word as surviving when the candidate has
    /// it or a near spelling of it. Fixing a misspelling removes the word
    /// as written, so a strict count reads "tomatos" becoming "tomatoes"
    /// as half the line lost, and the correction is refused: the one thing
    /// the check exists to allow.
    static func keptAllowingSpelling(of source: String, in candidate: String) -> Double {
        let from = words(source)
        guard !from.isEmpty else { return 1 }
        let to = words(candidate)
        return Double(from.filter { matches($0, in: to) }.count) / Double(from.count)
    }

    /// In the set exactly, or contained in it as a lone character, or —
    /// for spaced words only — near a word that is. A character pair never
    /// gets the spelling allowance: one edit to a two-character word is a
    /// different word, not a typo.
    static func matches(_ word: String, in set: Set<String>) -> Bool {
        if set.contains(word) { return true }
        if containsLone(word, in: set) { return true }
        if hasSpaceless(word) { return false }
        return set.contains(where: { near(word, $0) })
    }

    /// Two words are the same word differently spelt: one edit apart, or
    /// two for a long word. Cheap, and only ever asked about short words.
    /// Never about a spaceless script, where the same arithmetic reads
    /// "five thousand" as a typo for "three thousand".
    static func near(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if hasSpaceless(a) || hasSpaceless(b) { return false }
        if abs(a.count - b.count) > 2 { return false }
        // Two letters the wrong way round is the commonest typo there is,
        // and plain Levenshtein charges two edits for it.
        if swapped(a, b) { return true }
        let allowed = min(a.count, b.count) >= 6 ? 2 : 1
        return distance(a, b, limit: allowed) <= allowed
    }

    /// The same letters with one neighbouring pair the wrong way round:
    /// "teh" for "the".
    static func swapped(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        guard x.count == y.count, x.count >= 2 else { return false }
        let differing = x.indices.filter { x[$0] != y[$0] }
        guard differing.count == 2, differing[1] == differing[0] + 1 else { return false }
        return x[differing[0]] == y[differing[1]] && x[differing[1]] == y[differing[0]]
    }

    /// Levenshtein distance, given up on once it passes `limit`.
    static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var row = Array(0...y.count)
        for i in 1...x.count {
            var previous = row[0]
            row[0] = i
            var best = row[0]
            for j in 1...y.count {
                let insert = row[j] + 1
                let delete = row[j - 1] + 1
                let swap = previous + (x[i - 1] == y[j - 1] ? 0 : 1)
                previous = row[j]
                row[j] = min(insert, delete, swap)
                best = min(best, row[j])
            }
            if best > limit { return limit + 1 }
        }
        return row[y.count]
    }

    /// The candidate says only what the source says: every content word of
    /// it is in the source, or near a word that is, and it says something
    /// at all. `sharesWords` is the strict form; this one lets an
    /// inflection through ("hotel" for "hotels") without letting an
    /// invention through, and refuses a candidate made only of small words,
    /// which the strict form waves past because its word set is empty.
    static func grounded(_ candidate: String, in source: String, keeping: Double = 0.75) -> Bool {
        guard inventsNoFigure(candidate, in: source) else { return false }
        let mine = words(candidate)
        guard !mine.isEmpty else { return false }
        let theirs = words(source)
        return Double(mine.filter { matches($0, in: theirs) }.count) / Double(mine.count) >= keeping
    }

    /// The two are about the same length in words, within `tolerance`. A
    /// tidied line that grew or shrank more than that was rewritten.
    static func lengthClose(_ a: String, _ b: String, tolerance: Double = 0.4) -> Bool {
        let na = wordCount(a)
        let nb = wordCount(b)
        if na == 0 || nb == 0 { return na == nb }
        let longer = Double(max(na, nb))
        return Double(abs(na - nb)) / longer <= tolerance
    }

    /// Whether a tidied line is the same line, cleaned: still empty or still
    /// not, at least `keeping` of its content words kept, grown by no more
    /// than half (plus one word), and none of its neighbours' words pulled
    /// in. Fails, and the original stays, when the model rewrote the line
    /// or ran two lines together.
    static func tidyKeeps(_ was: String, _ now: String, others: [String], keeping: Double = 0.6) -> Bool {
        let before = was.trimmingCharacters(in: .whitespaces)
        let after = now.trimmingCharacters(in: .whitespaces)
        if before.isEmpty || after.isEmpty { return before.isEmpty == after.isEmpty }
        // The same letters and digits in the same order is the same line:
        // the edit was punctuation, case or accents, which is exactly what
        // a tidy is for. Decided on the characters themselves, so it is
        // exact where the ratios below are approximate — and it cannot be
        // fooled, because anything added or removed makes the strings
        // differ. "不用给牙医打电话" gets no free pass for containing
        // "给牙医打电话"; it is a different string.
        if bare(before) == bare(after) { return true }
        // Punctuation and spelling are what a tidy is for; numbers and days
        // are not. Every one the line said has to still be there, and one
        // the tidy added has to be the line's own misspelling put right.
        let said = figures(before), now = figures(after)
        guard said.isSubset(of: now) else { return false }
        guard now.subtracting(said).allSatisfy({ correcting($0, of: before) }) else { return false }
        guard keptAllowingSpelling(of: before, in: after) >= keeping else { return false }
        guard Double(wordCount(after)) <= Double(wordCount(before)) * 1.5 + 1 else { return false }
        return !absorbs(after, own: before, from: others)
    }

    /// Just the letters and numbers, folded: what a line says with its
    /// punctuation taken off.
    private static func bare(_ text: String) -> String {
        String(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber })
    }

    /// Whether `candidate` took words from another line: two or more of a
    /// neighbour's content words that its own original did not have.
    static func absorbs(_ candidate: String, own: String, from others: [String]) -> Bool {
        let mine = words(own)
        let has = words(candidate)
        return others.contains { other in
            words(other).subtracting(mine).intersection(has).count >= 2
        }
    }

    /// How many words this would be if it were spaced: whitespace chunks
    /// count one each, except that a chunk's spaceless characters count a
    /// word per pair. Two characters to a word is about right for Chinese
    /// and Japanese, and it is what keeps "a title of eight words at most"
    /// meaning the same thing in every script — a ten-character Chinese
    /// title used to be one "word", which made every length limit
    /// meaningless there.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).reduce(0) { total, chunk in
            var dense = 0
            var other = false
            for character in chunk {
                if isSpaceless(character) { dense += 1 }
                else if character.isLetter || character.isNumber { other = true }
            }
            guard dense > 0 else { return total + 1 }
            return total + (dense + 1) / 2 + (other ? 1 : 0)
        }
    }
}
