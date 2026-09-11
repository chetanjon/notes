import XCTest
@testable import Notes

final class TranscriptTests: XCTestCase {
    func testTheTailIsReplacedNotAppended() {
        var heard = Transcript()
        heard.revise("milk and")
        heard.revise("milk and eggs")
        XCTAssertEqual(heard.text, "milk and eggs")
    }

    func testASettledSegmentIsJoinedWithOneSpace() {
        var heard = Transcript()
        heard.revise("milk and eggs")
        heard.settle()
        heard.revise("and call the dentist")
        XCTAssertEqual(heard.text, "milk and eggs and call the dentist")
    }

    func testSettlingWithNothingHeardAddsNothing() {
        var heard = Transcript()
        heard.revise("milk")
        heard.settle()
        // A segment that heard silence: no stray space, no empty join.
        heard.settle()
        heard.settle()
        XCTAssertEqual(heard.text, "milk")
    }

    func testAFinalResultReplacesTheLastGuess() {
        var heard = Transcript()
        heard.revise("call the dentist tuesday")
        // The recogniser's final pass corrects what the partials said.
        heard.settle("Call the dentist Tuesday.")
        XCTAssertEqual(heard.text, "Call the dentist Tuesday.")
    }

    func testThereIsNeverALeadingOrDoubleSpace() {
        var heard = Transcript()
        heard.revise("  milk  ")
        heard.settle()
        heard.revise("  eggs  ")
        XCTAssertEqual(heard.text, "milk eggs")
    }

    func testAnEmptyTranscriptKnowsItIsEmpty() {
        var heard = Transcript()
        XCTAssertTrue(heard.isEmpty)
        heard.revise("   ")
        XCTAssertTrue(heard.isEmpty)
        heard.revise("milk")
        XCTAssertFalse(heard.isEmpty)
    }
}
