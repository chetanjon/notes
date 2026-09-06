import XCTest
@testable import Notes

final class NoteTextTests: XCTestCase {
    func testTitleIsFirstNonEmptyLine() {
        XCTAssertEqual(NoteText.title("Walking app\nVoice notes"), "Walking app")
        XCTAssertEqual(NoteText.title("\n\n  Second  \nThird"), "Second")
        XCTAssertEqual(NoteText.title("□ milk"), "milk")
        XCTAssertEqual(NoteText.title(""), "New note")
        XCTAssertEqual(NoteText.title("  \n□ "), "New note")
    }

    func testPlainPreviewJoinsBodyLines() {
        XCTAssertEqual(NoteText.preview("Title\nVoice notes\n\non walks"), "Voice notes on walks")
        XCTAssertEqual(NoteText.preview("Title"), "")
    }

    func testChecklistSummary() {
        let text = "Groceries\n■ eggs\n□ milk\n□ rice\n■ bread"
        XCTAssertTrue(NoteText.isChecklist(text))
        XCTAssertEqual(NoteText.checklistSummary(text), NoteText.Summary(done: 2, total: 4, open: ["milk", "rice"]))
        XCTAssertEqual(NoteText.preview(text), "2/4 done · milk, rice")
        XCTAssertEqual(NoteText.widgetPreview(text), "2/4 · milk, rice")
    }

    func testAllDone() {
        let text = "Groceries\n■ eggs\n■ milk"
        XCTAssertEqual(NoteText.preview(text), "All done")
        XCTAssertEqual(NoteText.widgetPreview(text), "All done")
    }

    func testWidgetPreviewIsFirstBodyLine() {
        XCTAssertEqual(NoteText.widgetPreview("Title\n\nfirst\nsecond"), "first")
        XCTAssertEqual(NoteText.widgetPreview("Title"), "")
    }

    func testStackListsOpenItemsAndCountsTheRest() {
        let text = "Groceries\n■ eggs\n□ milk\n□ rice\n□ bread\n□ tea\n□ salt"
        let stack = NoteText.stack(text, limit: 4)
        XCTAssertEqual(stack.lines, ["milk", "rice", "bread", "tea"])
        XCTAssertEqual(stack.more, 1)
        XCTAssertTrue(stack.isChecklist)
        XCTAssertEqual(stack.done, 1)
        XCTAssertEqual(stack.total, 6)
    }

    func testStackOfAPlainNoteIsItsBodyLines() {
        let stack = NoteText.stack("Title\n\nfirst\n  second  \nthird", limit: 2)
        XCTAssertEqual(stack.lines, ["first", "second"])
        XCTAssertEqual(stack.more, 1)
        XCTAssertFalse(stack.isChecklist)
        XCTAssertEqual(stack.total, 0)
    }

    func testStackOfAFinishedChecklistIsEmpty() {
        let stack = NoteText.stack("Groceries\n■ eggs\n■ milk")
        XCTAssertEqual(stack.lines, [])
        XCTAssertEqual(stack.more, 0)
        XCTAssertEqual(stack.done, 2)
        XCTAssertEqual(stack.total, 2)
    }

    func testBlankNotes() {
        XCTAssertTrue(NoteText.isBlank(""))
        XCTAssertTrue(NoteText.isBlank(" \n\n  "))
        XCTAssertTrue(NoteText.isBlank("□ \n■ "))
        XCTAssertFalse(NoteText.isBlank("a"))
        XCTAssertFalse(NoteText.isBlank("\n□ milk"))
    }

    func testSearchIsCaseInsensitiveOverTitleAndBody() {
        let text = "Walking app\nVoice notes on walks"
        XCTAssertTrue(NoteText.matches(text, query: "WALK"))
        XCTAssertTrue(NoteText.matches(text, query: "voice"))
        XCTAssertFalse(NoteText.matches(text, query: "running"))
        XCTAssertTrue(NoteText.matches(text, query: "   "))
    }
}
