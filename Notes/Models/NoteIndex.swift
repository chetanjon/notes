import CoreSpotlight
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The notes in the iPhone's own search index (Spotlight), so a note turns
/// up when the user searches from the Home Screen, and Siri can find it by
/// name. The index lives on the phone; nothing leaves it. App only: the
/// widget never writes it.
enum NoteIndex {
    static let domain = "note"

    /// Every note that is not in the Trash, rewritten on each foreground.
    /// That also covers what iCloud brought in or took away while the app
    /// was closed, which no save on this phone would have seen.
    static func reindex(in context: ModelContext) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        let items = notes.filter { !$0.isTrashed }.map(item)
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            index.indexSearchableItems(items) { _ in }
        }
    }

    static func index(_ note: Note) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().indexSearchableItems([item(note)]) { _ in }
    }

    static func remove(_ ids: [UUID]) {
        guard CSSearchableIndex.isIndexingAvailable(), !ids.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids.map(\.uuidString)) { _ in }
    }

    private static func item(_ note: Note) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = note.title
        attributes.contentDescription = note.preview
        attributes.textContent = note.text
        attributes.contentModificationDate = note.updatedAt
        let item = CSSearchableItem(uniqueIdentifier: note.id.uuidString,
                                    domainIdentifier: domain, attributeSet: attributes)
        item.expirationDate = .distantFuture
        return item
    }
}
