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

extension ModelGuardTests {
    func testTidyKeepsCleaningNotRewriting() {
        let others = ["This week", "i recieved the parcel , its fine"]
        XCTAssertTrue(ModelGuard.tidyKeeps("call teh dentist", "Call the dentist.", others: others))
        XCTAssertTrue(ModelGuard.tidyKeeps("milk eggs bread", "Milk, eggs, bread", others: others))
        XCTAssertTrue(ModelGuard.tidyKeeps("", "", others: others))
        XCTAssertFalse(ModelGuard.tidyKeeps("", "New line", others: others))
        XCTAssertFalse(ModelGuard.tidyKeeps("call teh dentist", "", others: others))
        // Rewritten: the words are gone.
        XCTAssertFalse(ModelGuard.tidyKeeps("call teh dentist", "Ring the tooth doctor", others: others))
        // Grown: more than half again.
        XCTAssertFalse(ModelGuard.tidyKeeps("milk", "Remember to buy some milk today", others: others))
        // Two lines run together: the neighbour's words came in.
        XCTAssertFalse(ModelGuard.tidyKeeps(
            "call teh dentist", "Call the dentist. I received the parcel, it's fine.", others: others))
    }

    func testAbsorbsNeedsTwoForeignWords() {
        XCTAssertTrue(ModelGuard.absorbs("Call the dentist, parcel fine", own: "call teh dentist", from: ["i recieved the parcel , its fine"]))
        XCTAssertFalse(ModelGuard.absorbs("Call the dentist about the parcel", own: "call teh dentist", from: ["i recieved the parcel , its fine"]))
        XCTAssertFalse(ModelGuard.absorbs("Milk, eggs, bread", own: "milk eggs bread", from: ["Groceries", "eggs and milk"]))
    }
}

extension ModelGuardTests {
    func testTidyKeepsAllowsASpellingFix() {
        // The corrected word is not the word that was there, so counting
        // exact survivors read a two-word line as half destroyed.
        XCTAssertTrue(ModelGuard.tidyKeeps("buy tomatos", "Buy tomatoes", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("wenesday meeting", "Wednesday meeting", others: []))
        XCTAssertTrue(ModelGuard.tidyKeeps("i recieved it", "I received it", others: []))
        // A different word is still a rewrite.
        XCTAssertFalse(ModelGuard.tidyKeeps("buy tomatos", "Buy potatoes and bread", others: []))
    }

    func testNearIsOneEditForShortWordsAndTwoForLong() {
        XCTAssertTrue(ModelGuard.near("tomatos", "tomatoes"))
        XCTAssertTrue(ModelGuard.near("teh", "the"))
        XCTAssertTrue(ModelGuard.near("hotel", "hotels"))
        XCTAssertFalse(ModelGuard.near("cat", "dog"))
        XCTAssertFalse(ModelGuard.near("milk", "bread"))
    }

    func testGroundedAllowsAnInflectionButNotAnInvention() {
        let note = "Japan trip\nHotels: one near the station, one by the park"
        XCTAssertTrue(ModelGuard.grounded("which hotel", in: note))
        XCTAssertTrue(ModelGuard.grounded("the stations", in: note))
        XCTAssertFalse(ModelGuard.grounded("book the flights", in: note))
        // Nothing but small words says nothing, and must not pass.
        XCTAssertFalse(ModelGuard.grounded("do it", in: note))
        XCTAssertFalse(ModelGuard.grounded("", in: note))
    }
}
