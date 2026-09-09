import Foundation

/// The pure side of "Notify me": how a notification is named, and which
/// pending ones a note no longer backs. Tested without the notification
/// centre.
enum NotifyPlan {
    /// One identifier per note and line, so setting the same line twice
    /// replaces rather than doubles.
    static func identifier(noteID: UUID, body: String) -> String {
        let folded = body.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "note.\(noteID.uuidString).\(fingerprint(folded))"
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
