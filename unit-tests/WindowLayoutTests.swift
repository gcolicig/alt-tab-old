import XCTest

final class WindowLayoutTests: XCTestCase {
    private let frame = CGRect(x: -1440, y: 25, width: 1440, height: 875)

    func testThirdsCoverVisibleFrame() {
        let left = WindowLayoutGeometry.frame(.leftThird, in: frame)!
        let right = WindowLayoutGeometry.frame(.rightThird, in: frame)!
        XCTAssertEqual(left, CGRect(x: -1440, y: 25, width: 480, height: 875))
        XCTAssertEqual(right, CGRect(x: -480, y: 25, width: 480, height: 875))
    }

    func testTwoThirdsCoverVisibleFrame() {
        let left = WindowLayoutGeometry.frame(.leftTwoThirds, in: frame)!
        let right = WindowLayoutGeometry.frame(.rightTwoThirds, in: frame)!
        XCTAssertEqual(left, CGRect(x: -1440, y: 25, width: 960, height: 875))
        XCTAssertEqual(right, CGRect(x: -960, y: 25, width: 960, height: 875))
    }

    func testThreeQuartersCoverVisibleFrame() {
        let left = WindowLayoutGeometry.frame(.leftThreeQuarters, in: frame)!
        let right = WindowLayoutGeometry.frame(.rightThreeQuarters, in: frame)!
        XCTAssertEqual(left, CGRect(x: -1440, y: 25, width: 1080, height: 875))
        XCTAssertEqual(right, CGRect(x: -1080, y: 25, width: 1080, height: 875))
    }

    func testUnevenWidthKeepsOuterEdgesExact() {
        let unevenFrame = CGRect(x: 12, y: -900, width: 1001, height: 900)
        let rightThird = WindowLayoutGeometry.frame(.rightThird, in: unevenFrame)!
        let rightTwoThirds = WindowLayoutGeometry.frame(.rightTwoThirds, in: unevenFrame)!
        let rightThreeQuarters = WindowLayoutGeometry.frame(.rightThreeQuarters, in: unevenFrame)!
        XCTAssertEqual(rightThird.maxX, unevenFrame.maxX)
        XCTAssertEqual(rightTwoThirds.maxX, unevenFrame.maxX)
        XCTAssertEqual(rightThreeQuarters.maxX, unevenFrame.maxX)
        XCTAssertEqual(rightThird.width, 334)
        XCTAssertEqual(rightTwoThirds.width, 668)
    }

    func testFocusLayoutsRevealAdjacentWindows() {
        let left = WindowLayoutGeometry.frame(.leftFocus, in: frame)!
        let center = WindowLayoutGeometry.frame(.centerFocus, in: frame)!
        let right = WindowLayoutGeometry.frame(.rightFocus, in: frame)!
        XCTAssertEqual(left, CGRect(x: -1440, y: 37, width: 1416, height: 851))
        XCTAssertEqual(center, CGRect(x: -1428, y: 25, width: 1416, height: 875))
        XCTAssertEqual(right, CGRect(x: -1416, y: 37, width: 1416, height: 851))
        XCTAssertEqual(left.minY - frame.minY, WindowLayoutGeometry.centerFocusVerticalReveal)
        XCTAssertEqual(right.minY - frame.minY, WindowLayoutGeometry.centerFocusVerticalReveal)
        XCTAssertEqual(frame.maxY - left.maxY, WindowLayoutGeometry.centerFocusVerticalReveal)
        XCTAssertEqual(frame.maxY - right.maxY, WindowLayoutGeometry.centerFocusVerticalReveal)
    }

    func testRestoreAndInvalidFramesHaveNoCalculatedFrame() {
        XCTAssertNil(WindowLayoutGeometry.frame(.restore, in: frame))
        XCTAssertNil(WindowLayoutGeometry.frame(.leftThird, in: .zero))
    }

    func testLayoutActionsHaveUniqueGlobalShortcutIds() {
        let keys = WindowLayoutAction.allCases.map(\.shortcutPreferenceKey)
        let ids = keys.compactMap { KeyboardEventsTestable.globalShortcutsIds[$0] }
        XCTAssertEqual(Set(keys).count, WindowLayoutAction.allCases.count)
        XCTAssertEqual(Set(ids).count, WindowLayoutAction.allCases.count)
    }
}
