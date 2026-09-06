import XCTest
@testable import Notes

final class TrashTests: XCTestCase {
    func testExpiresAfterThirtyDays() {
        let deleted = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 24 * 60 * 60
        XCTAssertFalse(Trash.isExpired(deletedAt: deleted, now: deleted))
        XCTAssertFalse(Trash.isExpired(deletedAt: deleted, now: deleted + 29 * day))
        XCTAssertTrue(Trash.isExpired(deletedAt: deleted, now: deleted + 30 * day))
        XCTAssertTrue(Trash.isExpired(deletedAt: deleted, now: deleted + 31 * day))
    }
}
