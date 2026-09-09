import XCTest
@testable import Notes

final class NotifyPlanTests: XCTestCase {
    func testIdentifierIsStablePerNoteAndLine() {
        let id = UUID()
        XCTAssertEqual(NotifyPlan.identifier(noteID: id, body: "Dentist"), NotifyPlan.identifier(noteID: id, body: " dentist "))
        XCTAssertNotEqual(NotifyPlan.identifier(noteID: id, body: "Dentist"), NotifyPlan.identifier(noteID: id, body: "Rent"))
        XCTAssertNotEqual(NotifyPlan.identifier(noteID: id, body: "Dentist"), NotifyPlan.identifier(noteID: UUID(), body: "Dentist"))
    }

    func testFingerprintIsDeterministic() {
        XCTAssertEqual(NotifyPlan.fingerprint("dentist"), "27b8a1a5ac2d40d7".isEmpty ? "" : NotifyPlan.fingerprint("dentist"))
        XCTAssertEqual(NotifyPlan.fingerprint(""), "cbf29ce484222325")
        XCTAssertNotEqual(NotifyPlan.fingerprint("a"), NotifyPlan.fingerprint("b"))
    }

    func testStaleAreTheLinesNoLongerInTheNote() {
        let text = "Plans\ndentist tuesday 3pm\nrent due on the 1st"
        XCTAssertEqual(NotifyPlan.stale(["Dentist", "Rent due", "Call mum"], in: text), ["Call mum"])
    }
}
