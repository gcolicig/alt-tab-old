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

    func testStepDirectionMovesOneStepTowardsTheTarget() {
        XCTAssertEqual(SpaceSwitchPlanner.stepDirection(currentIndex: 0, targetIndex: 3, spaceCount: 5), .right)
        XCTAssertEqual(SpaceSwitchPlanner.stepDirection(currentIndex: 4, targetIndex: 1, spaceCount: 5), .left)
        XCTAssertNil(SpaceSwitchPlanner.stepDirection(currentIndex: 2, targetIndex: 2, spaceCount: 5))
        XCTAssertNil(SpaceSwitchPlanner.stepDirection(currentIndex: 2, targetIndex: 5, spaceCount: 5))
        XCTAssertNil(SpaceSwitchPlanner.stepDirection(currentIndex: 2, targetIndex: 1, spaceCount: 0))
    }

    func testPredictionBridgesTheReportingGapOfAnInFlightSwitch() {
        let prediction = SpacePrediction(sourceIndex: 0, targetIndex: 3, timestamp: 100)
        XCTAssertEqual(SpacePredictionPolicy.baseIndex(observedIndex: 0, prediction: prediction, now: 100.1), 3)
        XCTAssertEqual(SpacePredictionPolicy.baseIndex(observedIndex: 3, prediction: prediction, now: 100.1), 3)
    }

    func testPredictionIsDiscardedWhenItExpiresOrRealityDisagrees() {
        let prediction = SpacePrediction(sourceIndex: 0, targetIndex: 3, timestamp: 100)
        // a dropped step lands somewhere else: plan from what the system reports
        XCTAssertEqual(SpacePredictionPolicy.baseIndex(observedIndex: 1, prediction: prediction, now: 100.1), 1)
        // an old prediction describes a switch that already settled or failed
        XCTAssertEqual(SpacePredictionPolicy.baseIndex(observedIndex: 0, prediction: prediction, now: 101), 0)
        XCTAssertEqual(SpacePredictionPolicy.baseIndex(observedIndex: 2, prediction: nil, now: 100), 2)
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
