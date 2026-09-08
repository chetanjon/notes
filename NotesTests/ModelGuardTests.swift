import XCTest
@testable import Notes

final class ModelGuardTests: XCTestCase {
    func testSharesWordsCatchesInventions() {
        let source = "milk eggs and call the dentist tuesday"
        XCTAssertTrue(ModelGuard.sharesWords("Call the dentist", with: source))
        XCTAssertTrue(ModelGuard.sharesWords("MILK", with: source))
        XCTAssertFalse(ModelGuard.sharesWords("Buy bread", with: source))
        // Short words carry nothing, so "a" and "to" never fail a check.
        XCTAssertTrue(ModelGuard.sharesWords("a to", with: source))
        XCTAssertTrue(ModelGuard.sharesWords("Café", with: "cafe at noon"))
        // Stop words carry nothing either.
        XCTAssertTrue(ModelGuard.sharesWords("the dentist and the milk", with: source))
        XCTAssertFalse(ModelGuard.words("when is the dentist").contains("the"))
    }

    func testKeptIsTheShareOfSourceWordsThatSurvive() {
        XCTAssertEqual(ModelGuard.kept(of: "milk eggs bread", in: "Milk and eggs"), 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(ModelGuard.kept(of: "", in: "anything"), 1)
    }

    func testLengthCloseAllowsFixesNotRewrites() {
        XCTAssertTrue(ModelGuard.lengthClose("call teh dentist", "Call the dentist."))
        XCTAssertTrue(ModelGuard.lengthClose("milk eggs bread tea", "Milk, eggs, bread, tea."))
        XCTAssertFalse(ModelGuard.lengthClose("milk", "Remember to buy some milk today"))
        XCTAssertTrue(ModelGuard.lengthClose("", ""))
        XCTAssertFalse(ModelGuard.lengthClose("", "new"))
    }
}
