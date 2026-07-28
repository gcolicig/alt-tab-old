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

    func testActionRegistryDispatchesAvailableAction() {
        var executionCount = 0
        let id = ActionIdentifier.windowLayout(.leftThird)
        let registry = ActionRegistry([
            RegisteredAction(id: id, title: "Left third", availability: { .available }) { executionCount += 1 },
        ])
        XCTAssertTrue(registry.perform(id))
        XCTAssertEqual(executionCount, 1)
        XCTAssertEqual(registry.action(id)?.title, "Left third")
    }

    func testActionRegistryRefusesUnavailableAndUnknownActions() {
        var executionCount = 0
        let id = ActionIdentifier.windowLayout(.leftThird)
        let registry = ActionRegistry([
            RegisteredAction(id: id, title: "Left third", availability: { .unavailable("Unavailable") }) { executionCount += 1 },
        ])
        XCTAssertFalse(registry.perform(id))
        XCTAssertFalse(registry.perform(.windowLayout(.rightThird)))
        XCTAssertEqual(registry.availability(id), .unavailable("Unavailable"))
        XCTAssertEqual(executionCount, 0)
    }

    func testActionIdentifiersAreStableAndUnique() {
        let ids = WindowLayoutAction.allCases.map { ActionIdentifier.windowLayout($0).stableId }
        XCTAssertEqual(Set(ids).count, WindowLayoutAction.allCases.count)
        XCTAssertEqual(ActionIdentifier.windowLayout(.centerFocus).stableId, "windowLayout.centerFocus")
    }

    func testDisplayOrderFollowsThePhysicalArrangement() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let below = CGRect(x: 0, y: 800, width: 1000, height: 800)
        XCTAssertEqual(DisplayMoveGeometry.orderedFrames([right, below, left]), [left, below, right])
    }

    func testDisplayMoveWrapsAndNeedsASecondDisplay() {
        XCTAssertEqual(DisplayMoveGeometry.targetScreenIndex(.nextDisplay, currentIndex: 0, screenCount: 3), 1)
        XCTAssertEqual(DisplayMoveGeometry.targetScreenIndex(.nextDisplay, currentIndex: 2, screenCount: 3), 0)
        XCTAssertEqual(DisplayMoveGeometry.targetScreenIndex(.previousDisplay, currentIndex: 0, screenCount: 3), 2)
        XCTAssertNil(DisplayMoveGeometry.targetScreenIndex(.nextDisplay, currentIndex: 0, screenCount: 1))
        XCTAssertNil(DisplayMoveGeometry.targetScreenIndex(.nextDisplay, currentIndex: 5, screenCount: 3))
    }

    func testDisplayMoveKeepsTheRelativePlacement() {
        let source = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let target = CGRect(x: 1000, y: 0, width: 2000, height: 1600)
        let leftHalf = CGRect(x: 0, y: 0, width: 500, height: 800)
        XCTAssertEqual(DisplayMoveGeometry.frame(leftHalf, from: source, to: target),
                       CGRect(x: 1000, y: 0, width: 1000, height: 1600))
    }

    func testDisplayMoveBoundsAWindowLargerThanTheTarget() {
        let source = CGRect(x: 0, y: 0, width: 2000, height: 1600)
        let target = CGRect(x: 2000, y: 0, width: 1000, height: 800)
        let full = CGRect(x: 0, y: 0, width: 2000, height: 1600)
        let moved = DisplayMoveGeometry.frame(full, from: source, to: target)
        XCTAssertEqual(moved, target)
        XCTAssertNil(DisplayMoveGeometry.frame(full, from: .zero, to: target))
    }
}
