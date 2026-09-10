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

    /// A full rewrite is not worth doing more often than this; every save
    /// on this phone indexes its own note at once anyway.
    static let reindexInterval: TimeInterval = 10 * 60
    /// Kept across launches: in memory alone, every cold launch rebuilt the
    /// whole index whether or not anything had changed.
    private static let lastReindexKey = "index.lastReindex"
    private static var lastReindex: Date? {
        get {
            let stamp = PinStore.suite.double(forKey: lastReindexKey)
            return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        }
        set { PinStore.suite.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lastReindexKey) }
    }

    /// Every note that is not in the Trash, rewritten on a foreground, at
    /// most every ten minutes. That also covers what iCloud brought in or
    /// took away while the app was closed, which no save on this phone
    /// would have seen.
    static func reindex(in context: ModelContext) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        if let last = lastReindex, Date.now.timeIntervalSince(last) < reindexInterval { return }
        lastReindex = .now
        guard let notes = try? context.fetch(FetchDescriptor<Note>()) else { return }
        let live = notes.filter { !$0.isTrashed }
        let gone = notes.filter { $0.isTrashed }.map(\.id)
        let index = CSSearchableIndex.default()
        // Added to rather than emptied and refilled: between a delete-all and
        // the refill the user's notes are missing from Spotlight, and if the
        // app is killed in that window they stay missing.
        index.indexSearchableItems(live.map(item)) { _ in }
        remove(gone)
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
