import Foundation

/// Where the Lock Screen card is in a long note. iOS caps a Live Activity
/// at about 160 points, so "show me the rest" cannot grow the card; it
/// pages instead: three rows normally, five smaller ones once expanded,
/// and "+N more" steps through the pages. Pure, so it is tested on Linux.
///
/// This is state of the card, not of the note: it lives only in the
/// running activity's content and resets when the activity does.
struct RowPage: Codable, Hashable {
    var index: Int = 0
    var expanded: Bool = false

    static let collapsedSize = 3
    static let expandedSize = 5

    var size: Int { expanded ? Self.expandedSize : Self.collapsedSize }

    func pageCount(rowCount: Int) -> Int {
        max(1, (rowCount + size - 1) / size)
    }

    /// The rows on this page.
    func visible<T>(_ rows: [T]) -> [T] {
        let start = min(index * size, rows.count)
        let end = min(start + size, rows.count)
        return Array(rows[start..<end])
    }

    /// Rows after this page, plus any the record left out.
    func remaining(rowCount: Int, more: Int) -> Int {
        more + max(0, rowCount - (index + 1) * size)
    }

    /// The same page, or the last one if rows went away.
    func clamped(rowCount: Int) -> RowPage {
        var page = self
        page.index = min(index, pageCount(rowCount: rowCount) - 1)
        return page
    }

    /// "+N more": the first tap expands to five rows; later taps turn the
    /// page; past the last page it comes back to the top, still expanded.
    func advanced(rowCount: Int) -> RowPage {
        var page = self
        if !expanded {
            page.expanded = true
            page.index = 0
        } else if index + 1 < pageCount(rowCount: rowCount) {
            page.index += 1
        } else {
            page.index = 0
        }
        return page
    }

    /// The title tapped: back to three rows at the top.
    func collapsed() -> RowPage {
        RowPage()
    }

    var isAtTop: Bool { index == 0 && !expanded }
}
