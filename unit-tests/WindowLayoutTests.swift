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

    func testUnevenWidthKeepsOuterEdgesExact() {
        let unevenFrame = CGRect(x: 12, y: -900, width: 1001, height: 900)
        let rightThird = WindowLayoutGeometry.frame(.rightThird, in: unevenFrame)!
        let rightTwoThirds = WindowLayoutGeometry.frame(.rightTwoThirds, in: unevenFrame)!
        XCTAssertEqual(rightThird.maxX, unevenFrame.maxX)
        XCTAssertEqual(rightTwoThirds.maxX, unevenFrame.maxX)
        XCTAssertEqual(rightThird.width, 334)
        XCTAssertEqual(rightTwoThirds.width, 668)
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
