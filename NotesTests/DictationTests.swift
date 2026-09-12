import XCTest
@testable import Notes

final class DictationTests: XCTestCase {
    func testComposePutsTheTitleFirstAndMakesBulletsItems() {
        let text = Dictation.compose(title: " Shop ", lines: ["", "Get these today", "- milk", "• eggs", "-  ", "call the dentist", ""])
        XCTAssertEqual(text, "Shop\nGet these today\n□ milk\n□ eggs\n\ncall the dentist")
    }

    func testComposeWithNothingIsEmpty() {
        XCTAssertEqual(Dictation.compose(title: "", lines: ["", " "]), "")
        XCTAssertEqual(Dictation.compose(title: "Only a title", lines: []), "Only a title")
    }

    func testPlainSplitsTheFirstSentenceOff() {
        XCTAssertEqual(Dictation.plain("Call the dentist. Tuesday at three, and ask about the crown"),
                       "Call the dentist\nTuesday at three, and ask about the crown")
        XCTAssertEqual(Dictation.plain("milk eggs and bread"), "milk eggs and bread")
        XCTAssertEqual(Dictation.plain("  "), "")
    }
}

extension DictationTests {
    func testPlainMakesAListFromPieces() {
        XCTAssertEqual(Dictation.plain("groceries, milk, eggs and bread"), "groceries\n□ milk\n□ eggs\n□ bread")
        XCTAssertEqual(Dictation.plain("Shop today. milk, eggs and bread"), "Shop today\n□ milk\n□ eggs\n□ bread")
        // Too few pieces to be a list.
        XCTAssertEqual(Dictation.plain("milk and eggs"), "milk and eggs")
        XCTAssertEqual(Dictation.plain("Idea. Record voice while walking"), "Idea\nRecord voice while walking")
    }
}

extension DictationTests {
    func testFillerIsNotCountedAsWordsSpoken() {
        XCTAssertEqual(Dictation.withoutFiller("um so like I basically need to call the dentist"),
                       "so I need to call the dentist")
        XCTAssertEqual(Dictation.withoutFiller("milk and eggs"), "milk and eggs")
    }

    func testSentenceEndIgnoresADecimal() {
        XCTAssertEqual(Dictation.plain("buy 2.5 kg of flour"), "buy 2.5 kg of flour")
        XCTAssertEqual(Dictation.plain("Shop. milk and eggs"), "Shop\nmilk and eggs")
    }
}

extension DictationTests {
    func testNothingIsSaidWhenThereIsNoModelToTidyWith() {
        // A permanent fact about the phone, not about this note. Saying it
        // after every dictation would be nagging, and the plain shaping is
        // a real answer rather than a failure.
        XCTAssertNil(Dictation.notice(for: .noModel))
    }

    func testNothingIsSaidWhenTheTidyingWorked() {
        // The text changing is the report, as it is for Make a list and
        // Sort the list, neither of which says anything when they work.
        XCTAssertNil(Dictation.notice(for: .cleaned("Shop\n□ milk")))
    }

    func testWhatWentWrongIsNamedWhenThereWasAModel() {
        XCTAssertEqual(Dictation.notice(for: .tooSlow), "That took too long")
        XCTAssertEqual(Dictation.notice(for: .tooLong), "Too long to tidy")
        XCTAssertEqual(Dictation.notice(for: .notTrusted), "Couldn't tidy that")
    }

    func testEveryNoticeFitsTheOneLineItIsGiven() {
        // The slot under the editor's bar is a single line at caption size.
        // A longer sentence is not shortened there, it is cut off.
        for outcome in [Dictation.Cleaning.tooSlow, .tooLong, .notTrusted] {
            XCTAssertTrue((Dictation.notice(for: outcome) ?? "").count <= 24)
        }
    }
}

extension DictationTests {
    func testSiriIsNotKeptWaitingTheWayTheEditorIs() {
        // An intent has to answer while somebody is listening to it. The
        // note is saved before the model is asked, so the whole cost of
        // giving up early is that it stays as the plain rules shaped it.
        XCTAssertLessThanOrEqual(Dictation.siriLimit, .seconds(5))
    }
}
