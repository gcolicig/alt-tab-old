import XCTest

final class InstantSpacesTests: XCTestCase {
    func testAdjacentPlansStopAtBounds() {
        XCTAssertNil(SpaceSwitchPlanner.plan(.left, currentIndex: 0, spaceCount: 3))
        XCTAssertEqual(SpaceSwitchPlanner.plan(.right, currentIndex: 0, spaceCount: 3),
                       SpaceSwitchPlan(direction: .right, steps: 1, targetIndex: 1))
        XCTAssertEqual(SpaceSwitchPlanner.plan(.left, currentIndex: 2, spaceCount: 3),
                       SpaceSwitchPlan(direction: .left, steps: 1, targetIndex: 1))
        XCTAssertNil(SpaceSwitchPlanner.plan(.right, currentIndex: 2, spaceCount: 3))
    }

    func testDirectPlansUseOneBasedIndexes() {
        XCTAssertEqual(SpaceSwitchPlanner.plan(.index(4), currentIndex: 0, spaceCount: 5),
                       SpaceSwitchPlan(direction: .right, steps: 3, targetIndex: 3))
        XCTAssertEqual(SpaceSwitchPlanner.plan(.index(1), currentIndex: 3, spaceCount: 5),
                       SpaceSwitchPlan(direction: .left, steps: 3, targetIndex: 0))
        XCTAssertNil(SpaceSwitchPlanner.plan(.index(4), currentIndex: 3, spaceCount: 5))
        XCTAssertNil(SpaceSwitchPlanner.plan(.index(6), currentIndex: 0, spaceCount: 5))
        XCTAssertNil(SpaceSwitchPlanner.plan(.index(0), currentIndex: 0, spaceCount: 5))
    }

    func testInvalidSnapshotsProduceNoPlan() {
        XCTAssertNil(SpaceSwitchPlanner.plan(.right, currentIndex: 0, spaceCount: 0))
        XCTAssertNil(SpaceSwitchPlanner.plan(.right, currentIndex: 3, spaceCount: 3))
    }

    func testDockOverlayRequiresBothObservedLayers() {
        XCTAssertFalse(SpaceSwitchPlanner.dockOverlayIsActive([]))
        XCTAssertFalse(SpaceSwitchPlanner.dockOverlayIsActive([18, 18]))
        XCTAssertFalse(SpaceSwitchPlanner.dockOverlayIsActive([20, 20]))
        XCTAssertTrue(SpaceSwitchPlanner.dockOverlayIsActive([18, 20]))
    }

    func testSpaceActionIdsAreUnique() {
        let ids = SpaceAction.all.map(\.stableId)
        XCTAssertEqual(Set(ids).count, SpaceAction.all.count)
    }

    func testSpaceActionShortcutKeysAreUniqueAndGlobal() {
        let keys = SpaceAction.all.map(\.shortcutPreferenceKey)
        XCTAssertEqual(Set(keys).count, SpaceAction.all.count)
        XCTAssertTrue(keys.allSatisfy(ControlsTab.isGlobalActionShortcut))
    }

    func testSpaceActionGlobalShortcutIdsAreUnique() {
        let ids = SpaceAction.all.compactMap { KeyboardEventsTestable.globalShortcutsIds[$0.shortcutPreferenceKey] }
        XCTAssertEqual(ids.count, SpaceAction.all.count)
        XCTAssertEqual(Set(ids).count, SpaceAction.all.count)
    }
}
