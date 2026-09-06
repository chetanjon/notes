import XCTest
@testable import Notes

final class RecentStoreTests: XCTestCase {
    private func note(_ title: String, age: TimeInterval, pinned: Bool = false) -> RecentStore.Summary {
        RecentStore.Summary(id: UUID(), title: title, preview: "", updatedAt: Date(timeIntervalSince1970: 1_000_000 - age), isPinned: pinned)
    }

    func testPinnedFirstThenNewest() {
        let old = note("old", age: 300)
        let new = note("new", age: 10)
        let pinned = note("pinned", age: 900, pinned: true)
        XCTAssertEqual(RecentStore.order([old, new, pinned]).map(\.title), ["pinned", "new", "old"])
    }

    func testCutToTheLimit() {
        let many = (0..<12).map { note("n\($0)", age: TimeInterval($0)) }
        let ordered = RecentStore.order(many)
        XCTAssertEqual(ordered.count, RecentStore.limit)
        XCTAssertEqual(ordered.first?.title, "n0")
        XCTAssertEqual(RecentStore.order([]), [])
    }
}
