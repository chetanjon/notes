import Foundation

/// A deleted note waits in the Trash, where a tap brings it back, until it
/// is deleted there or has sat for thirty days. Pure dates, so the rule is
/// testable without SwiftData.
enum Trash {
    /// How long a note stays before it is deleted for good.
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    static func isExpired(deletedAt: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(deletedAt) >= retention
    }
}
