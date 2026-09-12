import XCTest
@testable import Notes

final class HearingTests: XCTestCase {
    func testItAsksForWordsAtFirst() {
        XCTAssertEqual(Hearing.placeholder(silence: 0), "Say what the note should say.")
        XCTAssertEqual(Hearing.placeholder(silence: 5), "Say what the note should say.")
    }

    func testItSaysNothingIsHeardAfterAWhile() {
        XCTAssertEqual(Hearing.placeholder(silence: Hearing.quiet), "Nothing heard yet.")
        XCTAssertEqual(Hearing.placeholder(silence: 10), "Nothing heard yet.")
    }

    func testItNamesTheMicrophoneAfterLonger() {
        // The sheet cannot move, so the words are the only way to say that
        // nothing is arriving.
        XCTAssertEqual(Hearing.placeholder(silence: Hearing.silent),
                       "Nothing heard. The microphone may be covered or muted.")
        XCTAssertEqual(Hearing.placeholder(silence: 600),
                       "Nothing heard. The microphone may be covered or muted.")
    }

    func testTimeRunningBackwardsIsStillTheFirstPrompt() {
        // A clock that jumps, or a negative interval from a reset: the
        // opening line is the safe answer, never a warning.
        XCTAssertEqual(Hearing.placeholder(silence: -30), "Say what the note should say.")
    }
}

extension HearingTests {
    func testItSaysHowLongUntilTheWordingChanges() {
        // The listener sleeps exactly this long and then looks again, so
        // that nothing has to tick while someone is speaking.
        XCTAssertEqual(Hearing.next(after: 0), Hearing.quiet)
        XCTAssertEqual(Hearing.next(after: 5), 1)
        XCTAssertEqual(Hearing.next(after: Hearing.quiet), 9)
        XCTAssertEqual(Hearing.next(after: 14), 1)
    }

    func testThereIsNothingToWaitForOnceTheLastThingIsSaid() {
        XCTAssertNil(Hearing.next(after: Hearing.silent))
        XCTAssertNil(Hearing.next(after: 600))
    }
}
