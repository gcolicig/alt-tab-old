import XCTest

final class WindowResizeTests: XCTestCase {
    private let window = CGRect(x: 100, y: 100, width: 400, height: 300)

    func testTheQuadrantOfTheStartPointPicksTheCorner() {
        XCTAssertEqual(WindowResizeGeometry.anchor(for: CGPoint(x: 120, y: 120), in: window), .topLeft)
        XCTAssertEqual(WindowResizeGeometry.anchor(for: CGPoint(x: 480, y: 120), in: window), .topRight)
        XCTAssertEqual(WindowResizeGeometry.anchor(for: CGPoint(x: 120, y: 380), in: window), .bottomLeft)
        XCTAssertEqual(WindowResizeGeometry.anchor(for: CGPoint(x: 480, y: 380), in: window), .bottomRight)
    }

    /// The corner opposite the one being dragged must not move, otherwise a resize drifts the window.
    func testTheOppositeCornerStaysPut() {
        let grown = WindowResizeGeometry.frame(from: window, anchor: .bottomRight, delta: CGSize(width: 50, height: 40))
        XCTAssertEqual(grown.minX, window.minX)
        XCTAssertEqual(grown.minY, window.minY)
        XCTAssertEqual(grown.width, 450)
        XCTAssertEqual(grown.height, 340)

        let fromTopLeft = WindowResizeGeometry.frame(from: window, anchor: .topLeft, delta: CGSize(width: 50, height: 40))
        XCTAssertEqual(fromTopLeft.maxX, window.maxX)
        XCTAssertEqual(fromTopLeft.maxY, window.maxY)
        XCTAssertEqual(fromTopLeft.width, 350)
        XCTAssertEqual(fromTopLeft.height, 260)
    }

    func testShrinkingStopsAtTheMinimumWithoutMovingTheFixedEdge() {
        let squashed = WindowResizeGeometry.frame(from: window, anchor: .bottomRight, delta: CGSize(width: -1000, height: -1000))
        XCTAssertEqual(squashed.width, WindowResizeGeometry.minimumSize.width)
        XCTAssertEqual(squashed.height, WindowResizeGeometry.minimumSize.height)
        XCTAssertEqual(squashed.minX, window.minX)
        XCTAssertEqual(squashed.minY, window.minY)
    }

    /// Clamping has to push back the edge under the cursor, not the anchored one.
    func testClampingFromTheTopLeftKeepsTheBottomRightAnchored() {
        let squashed = WindowResizeGeometry.frame(from: window, anchor: .topLeft, delta: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(squashed.maxX, window.maxX)
        XCTAssertEqual(squashed.maxY, window.maxY)
        XCTAssertEqual(squashed.width, WindowResizeGeometry.minimumSize.width)
        XCTAssertEqual(squashed.height, WindowResizeGeometry.minimumSize.height)
    }

    func testMixedCornersResizeOnlyTheirOwnEdges() {
        let frame = WindowResizeGeometry.frame(from: window, anchor: .bottomLeft, delta: CGSize(width: -30, height: 20))
        XCTAssertEqual(frame.minX, 70)
        XCTAssertEqual(frame.maxX, window.maxX)
        XCTAssertEqual(frame.minY, window.minY)
        XCTAssertEqual(frame.maxY, 420)
    }

    func testTheModeFollowsWhicheverModifierMatches() {
        XCTAssertEqual(DragModeSelection.mode([.command, .shift], move: .commandShift, resize: .fn), .move)
        XCTAssertEqual(DragModeSelection.mode([.function], move: .commandShift, resize: .fn), .resize)
        XCTAssertNil(DragModeSelection.mode([.option], move: .commandShift, resize: .fn))
        XCTAssertNil(DragModeSelection.mode([.command, .shift], move: .disabled, resize: .fn))
    }

    func testTwoModulesMayNotShareOneModifier() {
        XCTAssertTrue(DragModeSelection.conflict(move: .commandShift, resize: .commandShift))
        XCTAssertFalse(DragModeSelection.conflict(move: .commandShift, resize: .fn))
        // both off is not a conflict, however identical the stored value looks
        XCTAssertFalse(DragModeSelection.conflict(move: .disabled, resize: .disabled))
    }
}
