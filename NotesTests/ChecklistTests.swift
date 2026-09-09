import XCTest
@testable import Notes

final class ChecklistTests: XCTestCase {
    func testToggleSwapsMarkers() {
        XCTAssertEqual(Checklist.toggle("□ milk"), "■ milk")
        XCTAssertEqual(Checklist.toggle("■ milk"), "□ milk")
        XCTAssertEqual(Checklist.toggle("milk"), "milk")
    }

    func testLineRangeExcludesTerminator() {
        let text = "Title\n□ milk\neggs"
        XCTAssertEqual(Checklist.lineRange(in: text, at: 0), NSRange(location: 0, length: 5))
        XCTAssertEqual(Checklist.lineRange(in: text, at: 7), NSRange(location: 6, length: 6))
        XCTAssertEqual(Checklist.line(in: text, at: 15), "eggs")
        // A cursor past the end clamps to the last line.
        XCTAssertEqual(Checklist.line(in: text, at: 99), "eggs")
    }

    func testToolbarButtonPrefixesAndStrips() {
        let plain = "Title\nmilk"
        let made = Checklist.toggleItem(in: plain, at: 8)
        XCTAssertEqual(made, Checklist.Edit(text: "Title\n□ milk", cursor: 10))
        let back = Checklist.toggleItem(in: made.text, at: made.cursor)
        XCTAssertEqual(back, Checklist.Edit(text: plain, cursor: 8))
    }

    func testStrippingKeepsCursorOnTheLine() {
        // Cursor right after the marker goes to the line start, not before it.
        let edit = Checklist.toggleItem(in: "a\n□ b", at: 3)
        XCTAssertEqual(edit, Checklist.Edit(text: "a\nb", cursor: 2))
    }

    func testTapOnMarkerToggles() {
        let text = "Title\n□ milk"
        XCTAssertTrue(Checklist.isOnMarker(in: text, at: 6))
        XCTAssertTrue(Checklist.isOnMarker(in: text, at: 7))
        XCTAssertFalse(Checklist.isOnMarker(in: text, at: 8))
        XCTAssertFalse(Checklist.isOnMarker(in: text, at: 0))
        XCTAssertEqual(Checklist.toggleDone(in: text, at: 6).text, "Title\n■ milk")
        XCTAssertEqual(Checklist.toggleDone(in: text, at: 2).text, text)
    }

    func testReturnContinuesTheList() {
        let text = "Title\n□ milk"
        let edit = Checklist.handleReturn(in: text, selection: NSRange(location: 12, length: 0))
        XCTAssertEqual(edit, Checklist.Edit(text: "Title\n□ milk\n□ ", cursor: 15))
    }

    func testReturnInTheMiddleSplitsTheItem() {
        let edit = Checklist.handleReturn(in: "□ milk", selection: NSRange(location: 4, length: 0))
        XCTAssertEqual(edit, Checklist.Edit(text: "□ mi\n□ lk", cursor: 7))
    }

    func testReturnOnEmptyItemEndsTheList() {
        let text = "Title\n□ milk\n□ "
        let edit = Checklist.handleReturn(in: text, selection: NSRange(location: 15, length: 0))
        XCTAssertEqual(edit, Checklist.Edit(text: "Title\n□ milk\n", cursor: 13))
    }

    func testReturnOnPlainLineIsLeftToTheTextView() {
        XCTAssertNil(Checklist.handleReturn(in: "Title\nmilk", selection: NSRange(location: 10, length: 0)))
    }

    func testDifferenceIsTheOneChangedRange() {
        let d1 = Checklist.difference(from: "Title\nmilk", to: "Title\n□ milk")
        XCTAssertEqual(d1.range, NSRange(location: 6, length: 0))
        XCTAssertEqual(d1.replacement, "□ ")
        let d2 = Checklist.difference(from: "Title\n■ milk", to: "Title\n□ milk")
        XCTAssertEqual(d2.range, NSRange(location: 6, length: 1))
        XCTAssertEqual(d2.replacement, "□")
        let d3 = Checklist.difference(from: "□ milk", to: "□ milk\n□ ")
        XCTAssertEqual(d3.range, NSRange(location: 6, length: 0))
        XCTAssertEqual(d3.replacement, "\n□ ")
        let d4 = Checklist.difference(from: "a\n□ ", to: "a\n")
        XCTAssertEqual(d4.range, NSRange(location: 2, length: 2))
        XCTAssertEqual(d4.replacement, "")
        let same = Checklist.difference(from: "x", to: "x")
        XCTAssertEqual(same.range, NSRange(location: 1, length: 0))
        XCTAssertEqual(same.replacement, "")
    }

    func testMarkerRangesAreWhatWritingToolsLeavesAlone() {
        let text = "Title\n□ milk\nplain\n■ eggs"
        let all = NSRange(location: 0, length: text.utf16.count)
        XCTAssertEqual(Checklist.markerRanges(in: text, within: all),
                       [NSRange(location: 6, length: 2), NSRange(location: 19, length: 2)])
        // Only markers inside the range count; the text of an item does not.
        XCTAssertEqual(Checklist.markerRanges(in: text, within: NSRange(location: 8, length: 11)), [])
        XCTAssertEqual(Checklist.markerRanges(in: text, within: NSRange(location: 12, length: 8)),
                       [NSRange(location: 19, length: 2)])
        XCTAssertEqual(Checklist.markerRanges(in: "no items", within: NSRange(location: 0, length: 8)), [])
        XCTAssertEqual(Checklist.markerRanges(in: text, within: NSRange(location: 40, length: 5)), [])
    }

    func testAppendingItemGoesOnItsOwnLineAtTheEnd() {
        XCTAssertEqual(Checklist.appendingItem("milk", to: "Groceries\n□ eggs"), "Groceries\n□ eggs\n□ milk")
        XCTAssertEqual(Checklist.appendingItem(" milk ", to: "Groceries\n□ eggs\n\n□ "), "Groceries\n□ eggs\n□ milk")
        XCTAssertEqual(Checklist.appendingItem("milk", to: "Groceries"), "Groceries\n□ milk")
        XCTAssertEqual(Checklist.appendingItem("milk", to: "Groceries\n"), "Groceries\n□ milk")
        // The title line is never dropped, even when empty.
        XCTAssertEqual(Checklist.appendingItem("milk", to: ""), "\n□ milk")
    }

    func testTickingFindsTheItemByItsWords() {
        let text = "Groceries\n□ Milk\n□ brown bread\n■ eggs\n□ bread"
        // Exact before contains: "bread" ticks the item that is "bread".
        let exact = Checklist.ticking("Bread", in: text)
        XCTAssertEqual(exact?.text, "Groceries\n□ Milk\n□ brown bread\n■ eggs\n■ bread")
        XCTAssertEqual(exact?.item, "bread")
        // Contains, either way round.
        XCTAssertEqual(Checklist.ticking("brown", in: text)?.item, "brown bread")
        XCTAssertEqual(Checklist.ticking("the milk please", in: text)?.item, "Milk")
        // A done item is not ticked again; nothing else matches.
        XCTAssertNil(Checklist.ticking("eggs", in: text))
        XCTAssertNil(Checklist.ticking("  ", in: text))
    }

    func testPlainBodyIsTheNonItemLines() {
        XCTAssertEqual(Checklist.plainBody(of: "Shop\nmilk, eggs\n□ bread\n\nand tea"), "milk, eggs\nand tea")
        XCTAssertEqual(Checklist.plainBody(of: "Shop\n□ bread"), "")
        XCTAssertEqual(Checklist.plainBody(of: "Shop"), "")
    }

    func testSplitMakesOneItemPerTask() {
        XCTAssertEqual(Checklist.split("milk eggs and call the dentist"), ["milk eggs", "call the dentist"])
        XCTAssertEqual(Checklist.split("milk, eggs; bread\n- tea\n• sugar\n1. rice\n2) beans"),
                       ["milk", "eggs", "bread", "tea", "sugar", "rice", "beans"])
        XCTAssertEqual(Checklist.split("  \n, ,\n"), [])
    }

    func testReplacingPlainBodyKeepsTitleAndTickedItems() {
        let edit = Checklist.replacingPlainBody(in: "Shop\n■ bread\nmilk and eggs", with: ["milk", " eggs"])
        XCTAssertEqual(edit.text, "Shop\n■ bread\n□ milk\n□ eggs")
        XCTAssertEqual(edit.cursor, edit.text.utf16.count)
    }

    func testAddingTitlePutsItOnANewFirstLine() {
        let edit = Checklist.addingTitle(" Weekend plans ", to: "call mum\n□ tickets")
        XCTAssertEqual(edit.text, "Weekend plans\ncall mum\n□ tickets")
        XCTAssertEqual(edit.cursor, "Weekend plans".utf16.count)
        XCTAssertEqual(Checklist.addingTitle("Title", to: "").text, "Title")
    }

    func testBareLinesDropTheMarkers() {
        XCTAssertEqual(Checklist.bareLines(of: "Shop\n□ milk\n\n■ eggs\nnote"), ["Shop", "milk", "", "eggs", "note"])
    }

    func testRestoringMarkersPutsThemBackLineForLine() {
        let original = "shop\n□ milk\n\n■ eggs\nnote"
        let restored = Checklist.restoringMarkers(from: original, lines: ["Shop", "Milk", "", "Eggs", "Note."])
        XCTAssertEqual(restored, "Shop\n□ Milk\n\n■ Eggs\nNote.")
        // A different number of lines cannot be matched up: nothing changes.
        XCTAssertNil(Checklist.restoringMarkers(from: original, lines: ["Shop", "Milk"]))
    }

    func testItemsAreTheItemTextsInOrder() {
        XCTAssertEqual(Checklist.items(of: "Shop\n□ milk\nnote\n■ eggs \n□ bread"), ["milk", "eggs", "bread"])
        XCTAssertEqual(Checklist.items(of: "Shop\nplain"), [])
    }

    func testReorderingMovesItemsAndKeepsTicksAndPlainLines() {
        let text = "Shop\n□ milk\nnote\n■ eggs\n□ bread"
        let edit = Checklist.reordering(items: [2, 0, 1], in: text)
        XCTAssertEqual(edit?.text, "Shop\n□ bread\nnote\n□ milk\n■ eggs")
        XCTAssertEqual(edit?.cursor, edit?.text.utf16.count)
        // Anything but a permutation of the items is refused.
        XCTAssertNil(Checklist.reordering(items: [0, 1], in: text))
        XCTAssertNil(Checklist.reordering(items: [0, 0, 1], in: text))
        XCTAssertNil(Checklist.reordering(items: [0, 1, 3], in: text))
    }

    func testReturnWithSelectionReplacesIt() {
        let edit = Checklist.handleReturn(in: "□ milk and eggs", selection: NSRange(location: 6, length: 9))
        XCTAssertEqual(edit, Checklist.Edit(text: "□ milk\n□ ", cursor: 9))
    }
}

extension ChecklistTests {
    func testAddingTitleReplacesThePlaceholderFirstLine() {
        let edit = Checklist.addingTitle("Walking app idea", to: "New note\nRecord voice notes")
        XCTAssertEqual(edit.text, "Walking app idea\nRecord voice notes")
        XCTAssertEqual(edit.cursor, "Walking app idea".utf16.count)
        XCTAssertEqual(Checklist.addingTitle("T", to: "new note").text, "T")
    }
}

extension ChecklistTests {
    func testBackspaceAfterTheMarkerTakesTheWholeMarker() {
        // The caret right after "□ ": backspace deletes the space, and the
        // marker goes with it, so the item is a plain line in one press.
        let edit = Checklist.handleDeletion(in: "Shop\n□ milk", range: NSRange(location: 6, length: 1))
        XCTAssertEqual(edit, Checklist.Edit(text: "Shop\nmilk", cursor: 5))
        // A selection that covers only the circle: the same.
        XCTAssertEqual(Checklist.handleDeletion(in: "□ milk", range: NSRange(location: 0, length: 1)),
                       Checklist.Edit(text: "milk", cursor: 0))
    }

    func testDeletingTheBreakBeforeAnItemDropsItsMarker() {
        // Backspace at the very start of an item joins it to the line above,
        // and the marker does not come along.
        let edit = Checklist.handleDeletion(in: "a\n□ b", range: NSRange(location: 1, length: 1))
        XCTAssertEqual(edit, Checklist.Edit(text: "ab", cursor: 1))
    }

    func testCutAcrossItemsLeavesNoBareMarker() {
        // From inside the first item's text through half of the second's
        // marker: the rest of the marker goes too.
        let text = "□ milk\n□ eggs"
        let edit = Checklist.handleDeletion(in: text, range: NSRange(location: 4, length: 4))
        XCTAssertEqual(edit, Checklist.Edit(text: "□ mieggs", cursor: 4))
        // A cut that already takes the whole marker needs no help.
        XCTAssertNil(Checklist.handleDeletion(in: text, range: NSRange(location: 4, length: 5)))
    }

    func testPlainDeletionsAreLeftToTheTextView() {
        XCTAssertNil(Checklist.handleDeletion(in: "Shop\n□ milk", range: NSRange(location: 10, length: 1)))
        XCTAssertNil(Checklist.handleDeletion(in: "Shop\nmilk", range: NSRange(location: 4, length: 1)))
        XCTAssertNil(Checklist.handleDeletion(in: "□ milk", range: NSRange(location: 3, length: 0)))
        XCTAssertNil(Checklist.handleDeletion(in: "□ milk", range: NSRange(location: 5, length: 9)))
    }

    func testItemFlags() {
        XCTAssertEqual(Checklist.itemFlags(of: "Shop\n□ milk\n\n■ eggs"), [false, true, false, true])
    }
}

extension ChecklistTests {
    func testToggleItemsOnASelectionMarksEveryLine() {
        let text = "Shop\nmilk\neggs\nbread"
        // From inside "milk" to inside "bread": three lines become items.
        let edit = Checklist.toggleItems(in: text, selection: NSRange(location: 6, length: 12))
        XCTAssertEqual(edit.text, "Shop\n□ milk\n□ eggs\n□ bread")
        XCTAssertEqual(edit.cursor, edit.text.utf16.count)
        // A mixed selection marks the plain ones and keeps the item.
        let mixed = Checklist.toggleItems(in: "Shop\n□ milk\neggs", selection: NSRange(location: 5, length: 10))
        XCTAssertEqual(mixed.text, "Shop\n□ milk\n□ eggs")
        // All items: the markers come off.
        let back = Checklist.toggleItems(in: edit.text, selection: NSRange(location: 5, length: 20))
        XCTAssertEqual(back.text, text)
        XCTAssertEqual(back.cursor, text.utf16.count)
        // A selection ending right after a line break does not take the next line.
        XCTAssertEqual(Checklist.toggleItems(in: text, selection: NSRange(location: 5, length: 5)).text, "Shop\n□ milk\neggs\nbread")
        // Nothing selected: the single-line button.
        XCTAssertEqual(Checklist.toggleItems(in: text, selection: NSRange(location: 6, length: 0)),
                       Checklist.toggleItem(in: text, at: 6))
    }
}
