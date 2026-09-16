import XCTest

final class FlickRingTests: XCTestCase {
    /// Inside the dead zone no direction is chosen, so a plain press of the button runs nothing.
    func testTheDeadZoneChoosesNoDirection() {
        XCTAssertNil(FlickRing.direction(dx: 0, dy: 0))
        XCTAssertNil(FlickRing.direction(dx: 3, dy: 3)) // hypot ~4.24 < 5
        XCTAssertNil(FlickRing.direction(dx: 4.9, dy: 0))
    }

    /// Just past the dead-zone radius a direction is chosen.
    func testClearingTheDeadZoneChoosesADirection() {
        XCTAssertEqual(FlickRing.direction(dx: 5, dy: 0), .right)
        XCTAssertEqual(FlickRing.direction(dx: 0, dy: 5), .up)
    }

    func testTheFourAxesMapToTheFourDirections() {
        XCTAssertEqual(FlickRing.direction(dx: 40, dy: 0), .right)
        XCTAssertEqual(FlickRing.direction(dx: -40, dy: 0), .left)
        XCTAssertEqual(FlickRing.direction(dx: 0, dy: 40), .up)
        XCTAssertEqual(FlickRing.direction(dx: 0, dy: -40), .down)
    }

    /// Each sector spans 90 degrees centred on its axis; points near the diagonals fall to the nearer axis.
    func testDiagonalsFallIntoTheNearerSector() {
        XCTAssertEqual(FlickRing.direction(dx: 40, dy: 39), .right) // just under 45 degrees
        XCTAssertEqual(FlickRing.direction(dx: 39, dy: 40), .up)    // just over 45 degrees
        XCTAssertEqual(FlickRing.direction(dx: -40, dy: 39), .left)
        XCTAssertEqual(FlickRing.direction(dx: -39, dy: -40), .down)
    }

    /// The +y-is-up contract: a screen delta whose y grows downward must be flipped by the caller, so a
    /// downward drag (negative dy here) is `down`, not `up`.
    func testUpAndDownAreDistinguishedByTheSignOfY() {
        XCTAssertEqual(FlickRing.direction(dx: 0, dy: 30), .up)
        XCTAssertEqual(FlickRing.direction(dx: 0, dy: -30), .down)
    }

    func testEveryDirectionHasAStableRawValue() {
        // the settings store persists these strings; they must stay put
        XCTAssertEqual(FlickDirection.allCases.map { $0.rawValue }, ["up", "right", "down", "left"])
    }
}
