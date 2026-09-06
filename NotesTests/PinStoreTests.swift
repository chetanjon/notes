import XCTest
@testable import Notes

final class PinStoreTests: XCTestCase {
    func testNoteURLCarriesTheID() {
        let id = UUID()
        let url = URL(string: "notes://note/\(id.uuidString)")!
        XCTAssertEqual(PinStore.noteID(from: url), id)
        XCTAssertNil(PinStore.noteID(from: URL(string: "notes://note/nope")!))
        XCTAssertNil(PinStore.noteID(from: URL(string: "https://example.com/note/\(id.uuidString)")!))
        XCTAssertNil(PinStore.noteID(from: PinStore.newNoteURL))
    }

    func testNewNoteURL() {
        XCTAssertTrue(PinStore.isNewNote(PinStore.newNoteURL))
        XCTAssertFalse(PinStore.isNewNote(URL(string: "notes://note/\(UUID().uuidString)")!))
        XCTAssertFalse(PinStore.isNewNote(URL(string: "https://example.com/new")!))
    }
}
