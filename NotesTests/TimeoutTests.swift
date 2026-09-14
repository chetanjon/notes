import XCTest
@testable import Notes

final class TimeoutTests: XCTestCase {
    func testItAnswersWhenTheWorkIsInTime() async {
        let answer = await withTimeout(.seconds(5)) { "done" }
        XCTAssertEqual(answer, "done")
    }

    func testItGivesUpAfterTheLimit() async {
        let answer = await withTimeout(.milliseconds(40)) { () -> String? in
            try? await Task.sleep(for: .seconds(5))
            return "too late"
        }
        XCTAssertNil(answer)
    }

    /// The one that matters. `withTimeout` waits on a continuation, and the
    /// two tasks it races are unstructured, so cancelling the caller used to
    /// reach none of it: the call sat here for the whole limit and then
    /// handed back the answer anyway.
    ///
    /// That is what let a dictation cleanup the user had cancelled — by
    /// starting to type — come back twenty seconds later and land on top of
    /// what they had written.
    func testACancelledCallerDoesNotWaitForTheWork() async {
        let started = ContinuousClock.now
        let job = Task { () -> String? in
            await withTimeout(.seconds(10)) { () -> String? in
                try? await Task.sleep(for: .seconds(10))
                return "too late"
            }
        }
        try? await Task.sleep(for: .milliseconds(50))
        job.cancel()
        let answer = await job.value
        XCTAssertNil(answer)
        let waited = ContinuousClock.now - started
        XCTAssertLessThanOrEqual(waited, .seconds(3))
    }

    /// Work that would have answered still answers nobody, once the caller
    /// has given up.
    func testTheAnswerIsDroppedAfterCancelling() async {
        let job = Task { () -> String? in
            await withTimeout(.seconds(10)) { () -> String? in
                try? await Task.sleep(for: .milliseconds(200))
                return "unwanted"
            }
        }
        try? await Task.sleep(for: .milliseconds(20))
        job.cancel()
        let answer = await job.value
        XCTAssertNil(answer)
    }
}
