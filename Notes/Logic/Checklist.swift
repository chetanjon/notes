import Foundation

/// Checklists are plain text. A line that starts with `□ ` is an open item
/// and one that starts with `■ ` is done. Everything here is string
/// manipulation on the line under the cursor; there is no rich text model.
///
/// Cursor positions are UTF-16 offsets, the unit `UITextView.selectedRange`
/// speaks, so the editor can pass them straight through. Both markers are a
/// single UTF-16 unit, so a marker with its space is always two units.
enum Checklist {
    static let open = "□ "
    static let done = "■ "
    /// Length of a marker plus its trailing space, in UTF-16 units.
    static let markerLength = 2

    static func isItem(_ line: Substring) -> Bool {
        line.hasPrefix(open) || line.hasPrefix(done)
    }

    static func isItem(_ line: String) -> Bool { isItem(line[...]) }

    static func isDone(_ line: String) -> Bool { line.hasPrefix(done) }

    /// Swaps an open marker for a done one and back. A line that is not an
    /// item comes back unchanged.
    static func toggle(_ line: String) -> String {
        if line.hasPrefix(done) { return open + line.dropFirst(markerLength) }
        if line.hasPrefix(open) { return done + line.dropFirst(markerLength) }
        return line
    }

    /// The text of an item without its marker; the line itself otherwise.
    static func content(_ line: String) -> String {
        isItem(line) ? String(line.dropFirst(markerLength)) : line
    }

    /// The result of an edit: the new text and where the cursor should land.
    struct Edit: Equatable {
        var text: String
        var cursor: Int
    }

    /// The range of the line containing `cursor`, without its line break.
    static func lineRange(in text: String, at cursor: Int) -> NSRange {
        let ns = text as NSString
        let location = max(0, min(cursor, ns.length))
        let full = ns.lineRange(for: NSRange(location: location, length: 0))
        var length = full.length
        // Trim the terminator: "\r\n", "\n", or "\r".
        if length > 0, ns.character(at: full.location + length - 1) == 0x0A { length -= 1 }
        if length > 0, ns.character(at: full.location + length - 1) == 0x0D { length -= 1 }
        return NSRange(location: full.location, length: length)
    }

    /// The line containing `cursor`, without its line break.
    static func line(in text: String, at cursor: Int) -> String {
        (text as NSString).substring(with: lineRange(in: text, at: cursor))
    }

    /// The toolbar button. A plain line becomes an open item; an item goes
    /// back to plain text. The cursor keeps its place in the line's content.
    static func toggleItem(in text: String, at cursor: Int) -> Edit {
        let ns = text as NSString
        let range = lineRange(in: text, at: cursor)
        let line = ns.substring(with: range)
        if isItem(line) {
            let replaced = ns.replacingCharacters(
                in: NSRange(location: range.location, length: markerLength), with: "")
            return Edit(text: replaced, cursor: max(range.location, cursor - markerLength))
        }
        let replaced = ns.replacingCharacters(
            in: NSRange(location: range.location, length: 0), with: open)
        return Edit(text: replaced, cursor: cursor + markerLength)
    }

    /// Tapping the marker. Flips open and done on the line containing
    /// `cursor`; a plain line is left alone.
    static func toggleDone(in text: String, at cursor: Int) -> Edit {
        let ns = text as NSString
        let range = lineRange(in: text, at: cursor)
        let line = ns.substring(with: range)
        guard isItem(line) else { return Edit(text: text, cursor: cursor) }
        return Edit(text: ns.replacingCharacters(in: range, with: toggle(line)), cursor: cursor)
    }

    /// Whether `offset` (a UTF-16 offset into `text`) sits on a marker, that
    /// is at position 0 or 1 of an item line.
    static func isOnMarker(in text: String, at offset: Int) -> Bool {
        let range = lineRange(in: text, at: offset)
        guard isItem((text as NSString).substring(with: range)) else { return false }
        return offset - range.location < markerLength
    }

    /// The marker (with its space) of every item line that overlaps `range`,
    /// in UTF-16 units. Writing Tools is told to leave these alone when it
    /// rewrites a note, so a rewritten checklist is still a checklist.
    static func markerRanges(in text: String, within range: NSRange) -> [NSRange] {
        let ns = text as NSString
        let end = min(NSMaxRange(range), ns.length)
        var found: [NSRange] = []
        var index = min(range.location, ns.length)
        while index < end {
            let line = lineRange(in: text, at: index)
            if isItem(ns.substring(with: line)) {
                let marker = NSRange(location: line.location, length: markerLength)
                if NSIntersectionRange(marker, range).length > 0 { found.append(marker) }
            }
            let next = ns.lineRange(for: NSRange(location: line.location, length: 0))
            if next.length == 0 { break }
            index = NSMaxRange(next)
        }
        return found
    }

    /// The text with `item` as a new open item on a line of its own at the
    /// end. Blank lines and an empty item at the end give way to it. What
    /// "add milk to Groceries" does from Siri.
    static func appendingItem(_ item: String, to text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while lines.count > 1, let last = lines.last,
              content(last).trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        lines.append(open + item.trimmingCharacters(in: .whitespacesAndNewlines))
        return lines.joined(separator: "\n")
    }

    /// "Tick milk off Groceries" from Siri: the first open item that is the
    /// words, or failing that the first that contains them (or that they
    /// contain), case and accents aside, marked done. The item's own text
    /// comes back so Siri can say it. Nil when nothing on the list matches.
    static func ticking(_ item: String, in text: String) -> (text: String, item: String)? {
        let wanted = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return nil }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        for exact in [true, false] {
            for (index, line) in lines.enumerated() where line.hasPrefix(open) {
                let content = self.content(line).trimmingCharacters(in: .whitespaces)
                guard !content.isEmpty else { continue }
                let hit = exact
                    ? content.compare(wanted, options: options) == .orderedSame
                    : content.range(of: wanted, options: options) != nil
                        || wanted.range(of: content, options: options) != nil
                if hit {
                    lines[index] = done + line.dropFirst(markerLength)
                    return (lines.joined(separator: "\n"), content)
                }
            }
        }
        return nil
    }

    /// The body's plain lines, the ones that are not items and not blank,
    /// joined with line breaks. What "Make a list" turns into items; the
    /// first line is the title and stays.
    static func plainBody(of text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
            .map(String.init)
            .filter { !isItem($0) && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }

    /// Items from plain text without a model: one per line, and within a
    /// line one per comma, semicolon, or " and "; bullets and numbering
    /// stripped, blanks dropped. "Make a list" on a phone without Apple
    /// Intelligence, and the fallback when the model has nothing to say.
    static func split(_ text: String) -> [String] {
        var items: [String] = []
        for line in text.split(separator: "\n") {
            let pieces = String(line)
                .replacingOccurrences(of: " and ", with: ",")
                .replacingOccurrences(of: ";", with: ",")
                .split(separator: ",")
            for piece in pieces {
                let item = strippingBullet(piece.trimmingCharacters(in: .whitespaces))
                if !item.isEmpty { items.append(item) }
            }
        }
        return items
    }

    /// "- milk", "• milk", "1. milk", "2) milk" → "milk".
    private static func strippingBullet(_ line: String) -> String {
        var item = line
        for bullet in ["- ", "• ", "* ", "– "] where item.hasPrefix(bullet) {
            item = String(item.dropFirst(bullet.count))
        }
        let digits = item.prefix(while: { $0.isNumber })
        if !digits.isEmpty, digits.count <= 2 {
            let rest = item.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") { item = String(rest.dropFirst(2)) }
        }
        return item.trimmingCharacters(in: .whitespaces)
    }

    /// The note with its plain body lines replaced by `items`, each an open
    /// item on a line of its own, after the title and the items already
    /// there (which keep their ticks). The cursor lands at the end.
    static func replacingPlainBody(in text: String, with items: [String]) -> Edit {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let title = lines.first ?? ""
        let kept = lines.dropFirst().filter(isItem)
        let made = items.map { open + $0.trimmingCharacters(in: .whitespaces) }
        let result = ([title] + kept + made).joined(separator: "\n")
        return Edit(text: result, cursor: (result as NSString).length)
    }

    /// "Add a title": the title on a new first line above everything that
    /// was there. The cursor lands at the end of the title, ready to change.
    static func addingTitle(_ title: String, to text: String) -> Edit {
        let line = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // A first line that is only the app's own "New note" is a placeholder,
        // not a title: it is replaced, not pushed down.
        if let first = lines.first,
           first.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(NoteText.untitled) == .orderedSame {
            lines[0] = line
            let result = lines.joined(separator: "\n")
            return Edit(text: result, cursor: (line as NSString).length)
        }
        let result = text.isEmpty ? line : line + "\n" + text
        return Edit(text: result, cursor: (line as NSString).length)
    }

    /// Every line with its marker taken off: what "Tidy up" hands the
    /// model, so a checklist reads as sentences and the markers are never
    /// in its hands.
    static func bareLines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { content(String($0)) }
    }

    /// The model's lines with `original`'s markers put back, line for line;
    /// nil when the counts differ, because then no line can be trusted to
    /// be the one it replaces. Done items stay done.
    static func restoringMarkers(from original: String, lines: [String]) -> String? {
        let old = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard old.count == lines.count else { return nil }
        return zip(old, lines).map { was, now -> String in
            let line = now.trimmingCharacters(in: .whitespaces)
            guard isItem(was) else { return line }
            return String(was.prefix(markerLength)) + line
        }.joined(separator: "\n")
    }

    /// The items' text, in order, ticked or not: what "Sort the list" hands
    /// the model.
    static func items(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter(isItem)
            .map { content($0).trimmingCharacters(in: .whitespaces) }
    }

    /// The item lines in a new order, `order` being every item's index
    /// exactly once, first for the top; each item keeps its tick, and the
    /// plain lines keep their places. Nil when `order` is not a permutation
    /// of the items, because then the list cannot be trusted. The cursor
    /// lands at the end.
    static func reordering(items order: [Int], in text: String) -> Edit? {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let slots = lines.indices.filter { isItem(lines[$0]) }
        guard order.count == slots.count, Set(order) == Set(slots.indices) else { return nil }
        let itemLines = slots.map { lines[$0] }
        for (slot, index) in zip(slots, order) { lines[slot] = itemLines[index] }
        let result = lines.joined(separator: "\n")
        return Edit(text: result, cursor: (result as NSString).length)
    }

    /// The one range that differs between two texts and what replaces it,
    /// in UTF-16 units: the longest common prefix and suffix are left alone.
    /// The editor applies checklist edits this way so they can be undone.
    static func difference(from old: String, to new: String) -> (range: NSRange, replacement: String) {
        let a = Array(old.utf16)
        let b = Array(new.utf16)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let range = NSRange(location: prefix, length: a.count - prefix - suffix)
        let replacement = String(decoding: b[prefix..<(b.count - suffix)], as: UTF16.self)
        return (range, replacement)
    }

    /// The Return key with `selection` about to be replaced by a line break.
    /// On an item with content, the list continues on a new line. On an
    /// empty item, the marker is removed and the list ends. On a plain line
    /// the answer is nil and the text view does what it always does.
    static func handleReturn(in text: String, selection: NSRange) -> Edit? {
        let ns = text as NSString
        let range = lineRange(in: text, at: selection.location)
        let line = ns.substring(with: range)
        guard isItem(line) else { return nil }
        // Return with a selection deletes it and continues from there.
        let afterDeletion = ns.replacingCharacters(in: selection, with: "")
        let cursor = selection.location
        let remaining = (afterDeletion as NSString).substring(
            with: lineRange(in: afterDeletion, at: cursor))
        if content(remaining).trimmingCharacters(in: .whitespaces).isEmpty {
            let lineStart = lineRange(in: afterDeletion, at: cursor).location
            let ended = (afterDeletion as NSString).replacingCharacters(
                in: NSRange(location: lineStart, length: remaining.utf16.count), with: "")
            return Edit(text: ended, cursor: lineStart)
        }
        let insertion = "\n" + open
        let continued = (afterDeletion as NSString).replacingCharacters(
            in: NSRange(location: cursor, length: 0), with: insertion)
        return Edit(text: continued, cursor: cursor + insertion.utf16.count)
    }
}
