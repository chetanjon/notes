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
