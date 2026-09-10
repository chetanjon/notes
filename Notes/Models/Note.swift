import Foundation
import SwiftData

/// A note is its text. The first line is the title; there is no separate
/// field for it. `isPinned` is true on at most one note, enforced in
/// `NoteStore.togglePin`, never by the schema. A note with a `deletedAt` is
/// in the Trash: out of the list, never pinned, gone for good thirty days
/// later. `openedAt` is the last time the editor showed the note; the list
/// is ordered by it, so a note read this morning sits above one edited
/// last week.
///
/// Every property has a default and none is unique, because CloudKit
/// requires the first and refuses the second.
@Model
final class Note {
    var id: UUID = UUID()
    /// Marked for CloudKit's own encryption, so the note's words are
    /// end-to-end where the user has Advanced Data Protection on, rather
    /// than readable to Apple under their keys. Nothing queries on it: the
    /// app's predicates only ever use `id`, `isPinned` and `deletedAt`, and
    /// an encrypted field cannot be queried. Set before the schema was
    /// first deployed, since adding it later is a migration.
    @Attribute(.allowsCloudEncryption) var text: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isPinned: Bool = false
    var deletedAt: Date? = nil
    var openedAt: Date? = nil

    init(text: String = "") {
        id = UUID()
        self.text = text
        createdAt = .now
        updatedAt = .now
        isPinned = false
        deletedAt = nil
        openedAt = .now
    }
}

extension Note {
    /// The later of the last opening and the last edit; what the list sorts
    /// by. An edit from another device counts, since it is news here too.
    var touchedAt: Date { max(openedAt ?? updatedAt, updatedAt) }

    var title: String { NoteText.title(text) }
    var bodyLines: [String] { NoteText.bodyLines(text) }
    var isChecklist: Bool { NoteText.isChecklist(text) }
    var checklistSummary: NoteText.Summary { NoteText.checklistSummary(text) }
    var preview: String { NoteText.preview(text) }
    var isBlank: Bool { NoteText.isBlank(text) }
    var isTrashed: Bool { deletedAt != nil }

    var pinned: PinStore.Pinned {
        let checklist = isChecklist
        let summary = checklist ? checklistSummary : NoteText.Summary(done: 0, total: 0, open: [])
        return PinStore.Pinned(
            id: id, title: title, preview: NoteText.widgetPreview(text), updatedAt: updatedAt,
            counters: NoteText.pinnedCounters(text), isChecklist: checklist,
            done: summary.done, total: summary.total)
    }
}
