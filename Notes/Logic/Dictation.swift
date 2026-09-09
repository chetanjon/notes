import Foundation

/// The note a dictation becomes. The model gives a title and the body as
/// lines, each marked as an item or not; `OnDevice` puts "- " in front of
/// the items and here they become the note's text, those lines as open
/// checklist items.
/// Pure, so it is tested without the model or the microphone.
enum Dictation {
    /// `title` on the first line, then the lines; a line that starts with
    /// "- ", "• " or "* " becomes an open checklist item. Blank lines at the
    /// ends go; a note with nothing in it is empty.
    static func compose(title: String, lines: [String]) -> String {
        let head = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // A bullet with nothing after it is an empty line.
            if ["-", "•", "*", "–"].contains(trimmed) { return "" }
            for bullet in ["- ", "• ", "* ", "– "] where trimmed.hasPrefix(bullet) {
                let item = trimmed.dropFirst(bullet.count).trimmingCharacters(in: .whitespaces)
                return item.isEmpty ? "" : Checklist.open + item
            }
            return trimmed
        }
        while body.last?.isEmpty == true { body.removeLast() }
        while body.first?.isEmpty == true { body.removeFirst() }
        if head.isEmpty, body.isEmpty { return "" }
        return ([head] + body).joined(separator: "\n")
    }

    /// A body with this many pieces (commas, "and", line breaks) is a list.
    static let listPieces = 3

    /// Without a model: the words as spoken, first sentence as the title.
    /// A body that reads as a list, "milk, eggs and bread", becomes items;
    /// with no sentence break at all, "groceries, milk, eggs and bread"
    /// takes its first piece as the title.
    static func plain(_ transcript: String) -> String {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        if let end = text.firstIndex(where: { ".!?".contains($0) }) {
            let title = text[..<end].trimmingCharacters(in: .whitespaces)
            let rest = text[text.index(after: end)...].trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, !rest.isEmpty {
                let pieces = Checklist.split(rest)
                if pieces.count >= listPieces { return compose(title: title, lines: pieces.map { "- " + $0 }) }
                return title + "\n" + rest
            }
        }
        let pieces = Checklist.split(text)
        if pieces.count > listPieces {
            return compose(title: pieces[0], lines: pieces.dropFirst().map { "- " + $0 })
        }
        return text
    }
}
