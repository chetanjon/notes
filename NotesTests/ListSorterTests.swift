import XCTest
@testable import Notes

final class ListSorterTests: XCTestCase {
    func testGroupsComeTogetherInOrderOfFirstAppearance() {
        let groups = [(1, "hardware"), (2, "Dairy"), (3, "hardware"), (4, "dairy")]
        XCTAssertEqual(ListSorter.order(groups: groups.map { (number: $0.0, group: $0.1) }, count: 4), [0, 2, 1, 3])
    }

    func testAlreadyGroupedIsNil() {
        let groups = [(1, "dairy"), (2, "dairy"), (3, "hardware")]
        XCTAssertNil(ListSorter.order(groups: groups.map { (number: $0.0, group: $0.1) }, count: 3))
    }

    func testBadNumbersAreRefused() {
        XCTAssertNil(ListSorter.order(groups: [(number: 1, group: "a"), (number: 1, group: "b")], count: 2))
        XCTAssertNil(ListSorter.order(groups: [(number: 1, group: "a"), (number: 3, group: "b")], count: 2))
        XCTAssertNil(ListSorter.order(groups: [(number: 1, group: "a")], count: 2))
        XCTAssertNil(ListSorter.order(groups: [], count: 0))
    }
}
