import XCTest
@testable import Notes

final class RowPageTests: XCTestCase {
    private let rows = Array(0..<7)

    func testTopShowsThreeAndCountsTheRest() {
        let page = RowPage()
        XCTAssertEqual(page.visible(rows), [0, 1, 2])
        XCTAssertEqual(page.remaining(rowCount: 7, more: 2), 6)
        XCTAssertEqual(page.pageCount(rowCount: 7), 3)
        XCTAssertTrue(page.isAtTop)
    }

    func testFirstTapExpandsToFiveAtTheTop() {
        let page = RowPage().advanced(rowCount: 7)
        XCTAssertTrue(page.expanded)
        XCTAssertEqual(page.index, 0)
        XCTAssertEqual(page.visible(rows), [0, 1, 2, 3, 4])
        XCTAssertEqual(page.remaining(rowCount: 7, more: 0), 2)
        XCTAssertEqual(page.pageCount(rowCount: 7), 2)
    }

    func testLaterTapsTurnPagesThenWrap() {
        let second = RowPage().advanced(rowCount: 7).advanced(rowCount: 7)
        XCTAssertEqual(second.index, 1)
        XCTAssertEqual(second.visible(rows), [5, 6])
        XCTAssertEqual(second.remaining(rowCount: 7, more: 0), 0)
        let wrapped = second.advanced(rowCount: 7)
        XCTAssertEqual(wrapped.index, 0)
        XCTAssertTrue(wrapped.expanded)
    }

    func testCollapseReturnsToTop() {
        let page = RowPage().advanced(rowCount: 12).advanced(rowCount: 12).collapsed()
        XCTAssertEqual(page, RowPage())
    }

    func testClampWhenRowsGoAway() {
        let page = RowPage(index: 2, expanded: true)
        XCTAssertEqual(page.clamped(rowCount: 12).index, 2)
        XCTAssertEqual(page.clamped(rowCount: 6).index, 1)
        XCTAssertEqual(page.clamped(rowCount: 0).index, 0)
        XCTAssertEqual(RowPage(index: 1, expanded: false).visible([Int]()), [])
    }

    func testNothingToPageForShortNotes() {
        let page = RowPage()
        XCTAssertEqual(page.remaining(rowCount: 3, more: 0), 0)
        XCTAssertEqual(page.advanced(rowCount: 3).advanced(rowCount: 3).index, 0)
    }
}
