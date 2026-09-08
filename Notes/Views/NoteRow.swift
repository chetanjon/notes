import SwiftUI

/// One note in the list: title, then the preview. No time: the list is in
/// order of use, and the editor says when a note was last edited. The Trash
/// alone puts a date in front of the preview, the day the note went in.
/// The rule underneath is the list's own separator, which stays put while
/// the row slides. Search matches are marked white on black.
struct NoteRow: View {
    let note: Note
    /// The search query to highlight, or empty.
    var highlight: String = ""
    /// A date to show before the preview, if any.
    var date: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marked(note.title, base: Theme.fg))
                    .font(Theme.Font.rowTitle)
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.fg)
                        .accessibilityLabel("Pinned")
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let date {
                    Text(DateFormat.when(date))
                        .font(Theme.Font.rowBody)
                        .monospacedDigit()
                        .foregroundStyle(Theme.fg)
                        .lineLimit(1)
                        .fixedSize()
                }
                Text(marked(note.preview, base: Theme.muted))
                    .font(Theme.Font.rowBody)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, Theme.rowPadding)
        .background(Theme.bg)
        .accessibilityElement(children: .combine)
    }

    /// The text with every occurrence of the query in white on black, in the
    /// style of an HTML `mark`.
    private func marked(_ string: String, base: Color) -> AttributedString {
        var attributed = AttributedString(string)
        attributed.foregroundColor = base
        let query = highlight.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return attributed }
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(
                of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].backgroundColor = Theme.fg
            attributed[range].foregroundColor = Theme.bg
            searchStart = range.upperBound
        }
        return attributed
    }
}
