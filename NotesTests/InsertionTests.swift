import XCTest
@testable import Notes

final class InsertionTests: XCTestCase {
    func testWordsSpokenAtTheEndOfAChecklistBecomeItems() {
        let landed = Insertion.landing("eggs and bread.", in: "Shop\n□ milk", at: NSRange(location: 11, length: 0))
        XCTAssertEqual(landed.text, "Shop\n□ milk\n□ eggs\n□ bread")
    }

    func testAnItemNeverKeepsTheFullStopTheRecogniserAdds() {
        // A line in a list is not a sentence, and punctuation is now asked
        // for, so every dictated item would otherwise end in a stop.
        let landed = Insertion.landing("eggs.", in: "Shop\n□ milk", at: NSRange(location: 11, length: 0))
        XCTAssertEqual(landed.text, "Shop\n□ milk\n□ eggs")
    }

    func testAnEmptyItemTakesTheFirstThingSaid() {
        // Rather than being left bare above the words it was waiting for.
        let landed = Insertion.landing("milk and eggs", in: "Shop\n□ ", at: NSRange(location: 7, length: 0))
        XCTAssertEqual(landed.text, "Shop\n□ milk\n□ eggs")
    }

    func testADoneItemKeepsItsTickWhenItemsGoInBelowIt() {
        let landed = Insertion.landing("eggs", in: "Shop\n■ milk", at: NSRange(location: 11, length: 0))
        XCTAssertEqual(landed.text, "Shop\n■ milk\n□ eggs")
    }

    func testWordsSpokenIntoAParagraphStayProse() {
        // Three pieces in a sentence are a sentence, not a list.
        let landed = Insertion.landing("milk, eggs and bread",
                                       in: "Shopping\nI need to get",
                                       at: NSRange(location: 22, length: 0))
        XCTAssertEqual(landed.text, "Shopping\nI need to get milk, eggs and bread")
    }

    func testWordsSpokenInsideALineGoInAtTheCursor() {
        let landed = Insertion.landing("about the lease", in: "call Priya", at: NSRange(location: 5, length: 0))
        XCTAssertEqual(landed.text, "call about the lease Priya")
    }

    func testASelectionIsWhatTheWordsAreSpokenOver() {
        let landed = Insertion.landing("Dara", in: "call Priya", at: NSRange(location: 5, length: 5))
        XCTAssertEqual(landed.text, "call Dara")
    }

    func testSpeakingIntoAnEmptyNoteWritesTheWords() {
        let landed = Insertion.landing("Ring the dentist", in: "", at: NSRange(location: 0, length: 0))
        XCTAssertEqual(landed.text, "Ring the dentist")
    }

    func testABlankLineTakesTheWordsWithoutAStraySpace() {
        let landed = Insertion.landing("Ring the dentist", in: "Shop\n", at: NSRange(location: 5, length: 0))
        XCTAssertEqual(landed.text, "Shop\nRing the dentist")
    }

    func testNothingSaidChangesNothing() {
        let landed = Insertion.landing("   ", in: "Shop\n□ milk", at: NSRange(location: 7, length: 0))
        XCTAssertEqual(landed.text, "Shop\n□ milk")
        XCTAssertEqual(landed.cursor, 7)
    }

    func testTheCursorLandsAfterTheWords() {
        let landed = Insertion.landing("eggs", in: "Shop\n□ milk", at: NSRange(location: 11, length: 0))
        XCTAssertEqual(landed.cursor, (landed.text as NSString).length)
    }

    func testTheCursorNeverLandsInsideAMarker() {
        // A cursor at the head of an item line sits before its circle.
        // Words put in there would break the marker in half.
        let landed = Insertion.landing("fresh", in: "Shop\n□ milk", at: NSRange(location: 5, length: 0))
        XCTAssertEqual(landed.text, "Shop\n□ fresh milk")
    }
}
