import Foundation

/// The pure side of "Notify me": how a notification is named, and which
/// pending ones a note no longer backs. Tested without the notification
/// centre.
enum NotifyPlan {
    /// One identifier per note, line and time, so setting the same line
    /// twice replaces rather than doubles, while two lines that read the
    /// same at different times ("standup tuesday 9am", "standup wednesday
    /// 9am") keep a notification each: iOS replaces by identifier, so
    /// without the time the second would silently swallow the first.
    static func identifier(noteID: UUID, body: String, due: Date) -> String {
        let folded = body.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "note.\(noteID.uuidString).\(fingerprint(folded)).\(Int(due.timeIntervalSince1970))"
    }

    /// FNV-1a over the bytes: the same line gives the same number on every
    /// launch, which Swift's own hashing does not promise.
    static func fingerprint(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    /// The pending bodies whose words are no longer all in the note: the
    /// line was removed or rewritten, so its notification should go.
    static func stale(_ bodies: [String], in text: String) -> [String] {
        bodies.filter { !ModelGuard.sharesWords($0, with: text) }
    }

    /// iOS keeps this many pending notifications per app; past it, the
    /// oldest due would be dropped, so the app refuses to add more.
    static let pendingLimit = 60
}
