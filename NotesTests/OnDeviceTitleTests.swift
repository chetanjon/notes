import XCTest
@testable import Notes

/// The rule for a title the model wrote. `OnDevice.title(for:)` needs the
/// model and a phone; the decision it makes does not, and this is it.
///
/// The title is not a suggestion. `EditorView.addTitle` writes it into the
/// note as a new first line, so whatever passes here is in the user's text
/// until they shake it out.
final class OnDeviceTitleTests: XCTestCase {
    private let note = "call the dentist tuesday\nmilk and eggs\nrent 3500 due friday"

    func testATitleMustSaySomethingAndBeShort() {
        XCTAssertFalse(OnDevice.titleFits("", for: note))
        XCTAssertFalse(OnDevice.titleFits("   ", for: note))
        XCTAssertFalse(OnDevice.titleFits(
            "the dentist and the milk and the eggs and the rent and friday", for: note))
        XCTAssertTrue(OnDevice.titleFits("Dentist and milk", for: note))
    }

    func testTheFirstLineHandedBackIsNotATitle() {
        XCTAssertFalse(OnDevice.titleFits("call the dentist tuesday", for: note))
        // Case and accents are not a difference either.
        XCTAssertFalse(OnDevice.titleFits("Call The Dentist Tuesday", for: note))
    }

    func testATitleIsGroundedInTheNote() {
        // The reminder path at OnDevice.reminders has always dropped a title
        // made of words the note does not say. This path never did, and it
        // is the one that writes into the note.
        XCTAssertFalse(OnDevice.titleFits("Book the flights", for: note))
        XCTAssertFalse(OnDevice.titleFits("Dentist wednesday", for: note))
        XCTAssertFalse(OnDevice.titleFits("Rent 3800", for: note))
        // A title made only of small words says nothing and must not pass.
        XCTAssertFalse(OnDevice.titleFits("To do", for: note))
    }

    func testAGroundedTitleStillPasses() {
        // Nothing calibrated tighter than it needs to be: an inflection and
        // a reordering are both still a title of this note.
        XCTAssertTrue(OnDevice.titleFits("Dentist and rent", for: note))
        XCTAssertTrue(OnDevice.titleFits("Milk, eggs, dentist", for: note))
        XCTAssertTrue(OnDevice.titleFits("Rent 3500", for: note))
    }
}
