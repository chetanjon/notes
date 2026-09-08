import XCTest
@testable import Notes

final class ListMakerTests: XCTestCase {
    func testKeepDropsInventedAndRepeatedItems() {
        let text = "milk eggs and call the dentist tuesday"
        let kept = ListMaker.keep(["Milk", " eggs ", "Buy bread", "milk", "call the dentist tuesday", ""], from: text)
        XCTAssertEqual(kept, ["Milk", "eggs", "call the dentist tuesday"])
    }

    func testKeepStopsAtTheLimit() {
        let words = (1...40).map { "item\($0)" }
        let kept = ListMaker.keep(words, from: words.joined(separator: " "))
        XCTAssertEqual(kept.count, ListMaker.maxItems)
    }
}
