import Foundation

/// Spoken words landing in a note that is already open: at the cursor, in
/// the form of the line they land on. Items where the cursor is in a
/// checklist, prose where it is in a paragraph.
///
/// The keyboard's own microphone key already puts words at the cursor.
/// What it cannot do is know that a note is a list, so dictating three
/// things into a checklist gives one long line instead of three items.
/// That shaping is the whole reason this exists, and being pure it is
/// settled by tests rather than by the simulator.
enum Insertion {
    static func landing(_ spoken: String, in text: String, at selection: NSRange) -> Checklist.Edit {
        let words = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let whole = text as NSString
        let asked = max(0, min(selection.location, whole.length))
        guard !words.isEmpty else { return Checklist.Edit(text: text, cursor: asked) }

        // A selection is what the words were spoken over, so it goes first.
        var body = text
        var cursor = asked
        if selection.length > 0, NSMaxRange(selection) <= whole.length {
            body = whole.replacingCharacters(in: selection, with: "")
            cursor = selection.location
        }

        let note = body as NSString
        cursor = max(0, min(cursor, note.length))
        let line = Checklist.lineRange(in: body, at: cursor)
        let content = note.substring(with: line)
        let isItem = Checklist.isItem(content)
        let end = NSMaxRange(line)
        // A cursor at the head of an item line sits before its marker.
        // Words put in there would break the circle in half.
        let place = max(line.location + (isItem ? Checklist.markerLength : 0), cursor)

        // Mid-line: the user is patching a line, not adding to a list.
        if place < end { return inserting(words, into: body, at: place) }

        let bare = Checklist.content(content).trimmingCharacters(in: .whitespaces)

        if isItem {
            let items = Checklist.split(words).map(item).filter { !$0.isEmpty }
            guard !items.isEmpty else { return Checklist.Edit(text: body, cursor: cursor) }
            let written = items.map { Checklist.open + $0 }.joined(separator: "\n")
            // An item with nothing in it takes the first thing said, rather
            // than being left bare above the rest.
            let replacing = bare.isEmpty ? line : NSRange(location: end, length: 0)
            let put = bare.isEmpty ? written : "\n" + written
            return Checklist.Edit(text: note.replacingCharacters(in: replacing, with: put),
                                  cursor: replacing.location + (put as NSString).length)
        }

        // A blank line takes the words outright; a line with words on it
        // carries on, because someone wanting a new line would have pressed
        // return.
        if bare.isEmpty {
            return Checklist.Edit(text: note.replacingCharacters(in: line, with: words),
                                  cursor: line.location + (words as NSString).length)
        }
        return inserting(words, into: body, at: end)
    }

    /// The words at `place`, with a space either side only where one is
    /// missing, so nothing is ever run together or doubly spaced.
    private static func inserting(_ words: String, into text: String, at place: Int) -> Checklist.Edit {
        let note = text as NSString
        var piece = words
        if place > 0, !isBlank(note.substring(with: NSRange(location: place - 1, length: 1))) {
            piece = " " + piece
        }
        if place < note.length, !isBlank(note.substring(with: NSRange(location: place, length: 1))) {
            piece += " "
        }
        return Checklist.Edit(text: note.replacingCharacters(in: NSRange(location: place, length: 0), with: piece),
                              cursor: place + (piece as NSString).length)
    }

    private static func isBlank(_ character: String) -> Bool {
        character.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }

    /// A spoken item, without the full stop the recogniser now puts on the
    /// end of everything. A line in a list is not a sentence.
    private static func item(_ piece: String) -> String {
        var text = piece.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix(".") { text.removeLast() }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
