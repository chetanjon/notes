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

    func testAPartialAnswerStillGroupsWhatItLabelled() {
        // The model labelled three of four; the fourth keeps its place.
        let groups = [(number: 1, group: "hardware"), (number: 2, group: "dairy"), (number: 4, group: "hardware")]
        XCTAssertEqual(ListSorter.order(groups: groups, count: 4), [0, 3, 1, 2])
    }

    func testOneKindForEverythingIsNotAGrouping() {
        let groups = [(number: 1, group: "shop"), (number: 2, group: "shop"), (number: 3, group: "shop")]
        XCTAssertNil(ListSorter.order(groups: groups, count: 3))
    }

    func testOutcomeTellsAGarbageAnswerFromAGroupedList() {
        // Two kinds, already in that order: nothing to move.
        XCTAssertEqual(ListSorter.outcome(groups: [(number: 1, group: "a"), (number: 2, group: "b")], count: 2),
                       ListSorter.Outcome.alreadyGrouped)
        // Two kinds, interleaved: a new order.
        XCTAssertEqual(ListSorter.outcome(groups: [(number: 1, group: "b"), (number: 2, group: "a"), (number: 3, group: "b")], count: 3),
                       ListSorter.Outcome.order([0, 2, 1]))
        // Every label blank, or every number out of range: nothing was said.
        XCTAssertEqual(ListSorter.outcome(groups: [(number: 1, group: "  "), (number: 2, group: "")], count: 2), ListSorter.Outcome.noAnswer)
        XCTAssertEqual(ListSorter.outcome(groups: [(number: 9, group: "dairy")], count: 2), ListSorter.Outcome.noAnswer)
        XCTAssertEqual(ListSorter.outcome(groups: [], count: 2), ListSorter.Outcome.noAnswer)
        // Labelled, but all the same kind: there is nothing to regroup.
        XCTAssertEqual(ListSorter.outcome(groups: [(number: 1, group: "shop"), (number: 2, group: "shop")], count: 2),
                       ListSorter.Outcome.alreadyGrouped)
    }

    func testBadNumbersAreRefused() {
        // A repeated number: the second is ignored, so one kind is named
        // and there is nothing to group by.
        XCTAssertNil(ListSorter.order(groups: [(number: 1, group: "a"), (number: 1, group: "b")], count: 2))
        // A number out of range is ignored.
        XCTAssertNil(ListSorter.order(groups: [(number: 1, group: "a"), (number: 3, group: "b")], count: 2))
        XCTAssertNil(ListSorter.order(groups: [], count: 0))
    }
}
