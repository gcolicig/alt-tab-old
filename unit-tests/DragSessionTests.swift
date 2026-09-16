import XCTest

final class DragSessionTests: XCTestCase {
    private func run(_ events: [DragSessionEvent], from state: DragSessionState = .idle) -> DragSessionState {
        events.reduce(state) { DragSessionMachine.next($0, $1) ?? $0 }
    }

    func testTheHappyPathReachesFinishingAndReturnsToIdle() {
        XCTAssertEqual(run([.modifierEngaged]), .armed)
        XCTAssertEqual(run([.modifierEngaged, .mouseDown]), .resolving)
        XCTAssertEqual(run([.modifierEngaged, .mouseDown, .windowResolved]), .dragging)
        XCTAssertEqual(run([.modifierEngaged, .mouseDown, .windowResolved, .mouseDragged, .mouseUp]), .finishing)
        XCTAssertEqual(run([.modifierEngaged, .mouseDown, .windowResolved, .mouseUp, .applied]), .idle)
    }

    func testAnUnresolvedWindowEndsTheSessionWithoutTouchingAnything() {
        let state = run([.modifierEngaged, .mouseDown, .windowUnresolved])
        XCTAssertEqual(state, .idle)
        XCTAssertFalse(DragSessionMachine.mayApplyFrame(state))
    }

    /// Letting go of the modifier while the button is still down must not drop the window mid-move.
    func testReleasingTheModifierDuringTheDragKeepsDragging() {
        XCTAssertEqual(run([.modifierEngaged, .mouseDown, .windowResolved, .modifierReleased, .mouseDragged]), .dragging)
    }

    func testReleasingTheModifierBeforeAnyClickDisarms() {
        XCTAssertEqual(run([.modifierEngaged, .modifierReleased]), .idle)
    }

    func testAbortCancelsFromEveryActiveStateButNotFromIdle() {
        XCTAssertEqual(run([.modifierEngaged, .aborted]), .cancelled)
        XCTAssertEqual(run([.modifierEngaged, .mouseDown, .aborted]), .cancelled)
        XCTAssertEqual(run([.modifierEngaged, .mouseDown, .windowResolved, .aborted]), .cancelled)
        XCTAssertNil(DragSessionMachine.next(.idle, .aborted))
    }

    func testACancelledSessionNeverWritesAFrame() {
        let state = run([.modifierEngaged, .mouseDown, .windowResolved, .aborted])
        XCTAssertFalse(DragSessionMachine.mayApplyFrame(state))
        XCTAssertEqual(run([.applied], from: state), .idle)
    }

    func testOnlyFinishingMayWriteAFrame() {
        XCTAssertTrue(DragSessionMachine.mayApplyFrame(.finishing))
        [DragSessionState.idle, .armed, .resolving, .dragging, .cancelled].forEach {
            XCTAssertFalse(DragSessionMachine.mayApplyFrame($0), "\($0)")
        }
    }

    func testStrayEventsAreIgnoredRatherThanAdvancingTheSession() {
        XCTAssertNil(DragSessionMachine.next(.idle, .mouseDown))
        XCTAssertNil(DragSessionMachine.next(.idle, .mouseUp))
        XCTAssertNil(DragSessionMachine.next(.armed, .mouseDragged))
        XCTAssertNil(DragSessionMachine.next(.dragging, .mouseDown))
    }

    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testAFreeEdgeSnapsImmediately() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 1, y: 400), visibleFrame: screen)), .leftHalf)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 999, y: 400), visibleFrame: screen)), .rightHalf)
    }

    /// A shared edge is a normal cursor move onto the next display, so distance alone must not snap.
    func testASharedEdgeNeedsDwell() {
        let atEdge = CGPoint(x: 1, y: 400)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: atEdge, visibleFrame: screen, hasNeighbourLeft: true, dwellElapsed: 0.05)), .none)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: atEdge, visibleFrame: screen, hasNeighbourLeft: true, dwellElapsed: 0.25)), .leftHalf)
    }

    /// Quartz coordinates: the top edge is minY. Swapping these would put the fill zone on the Dock edge.
    /// Displays stack vertically too. With one directly above, the top edge is a route to it rather than a
    /// fill target, and treating it as free made both fill and the menubar drop unreachable.
    /// A display above turns the top edge into a route, and no amount of dwell makes it a target: while the
    /// cursor passes through, the overlay appeared and the window flickered between the two screens.
    func testThereIsNoFillZoneWhenADisplaySitsAbove() {
        let atTop = CGPoint(x: 500, y: 1)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: atTop, visibleFrame: screen, hasNeighbourAbove: true, dwellElapsed: 0.05)), .none)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: atTop, visibleFrame: screen, hasNeighbourAbove: true, dwellElapsed: 5)), .none)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: atTop, visibleFrame: screen, hasNeighbourAbove: false)), .fill)
    }

    func testNeighbourDetectionSeesDisplaysStackedAbove() {
        let lower = CGRect(x: 0, y: 0, width: 2560, height: 1707)
        let upper = CGRect(x: 0, y: -1440, width: 2560, height: 1440)
        XCTAssertTrue(DragScreenNeighbours.hasNeighbourAbove(lower, among: [lower, upper]))
        XCTAssertFalse(DragScreenNeighbours.hasNeighbourAbove(upper, among: [lower, upper]))
        // side by side is not above, however close
        let beside = CGRect(x: 2560, y: 0, width: 1000, height: 1707)
        XCTAssertFalse(DragScreenNeighbours.hasNeighbourAbove(lower, among: [lower, beside]))
    }

    func testTheTopEdgeFillsAndTheBottomEdgeIsInert() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 500, y: 0), visibleFrame: screen)), .fill)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 500, y: 799), visibleFrame: screen)), .none)
    }

    func testNeighbourDetectionNeedsTouchingEdgesAndOverlappingRows() {
        let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let leftOf = CGRect(x: -1000, y: 0, width: 1000, height: 800)
        let rightOf = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let diagonal = CGRect(x: -1000, y: 900, width: 1000, height: 800)
        XCTAssertTrue(DragScreenNeighbours.hasNeighbour(left: true, of: main, among: [main, leftOf]))
        XCTAssertTrue(DragScreenNeighbours.hasNeighbour(left: false, of: main, among: [main, rightOf]))
        XCTAssertFalse(DragScreenNeighbours.hasNeighbour(left: true, of: main, among: [main, rightOf]))
        // stacked diagonally: the edges touch in x but the rows do not overlap
        XCTAssertFalse(DragScreenNeighbours.hasNeighbour(left: true, of: main, among: [main, diagonal]))
        XCTAssertFalse(DragScreenNeighbours.hasNeighbour(left: true, of: main, among: [main]))
    }

    func testEdgeReportsThePositionEvenWhereTheTargetWouldBeUnavailable() {
        // the edge is still an edge; only `target` decides whether it may be used yet
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 1, y: 400), screen), .leftHalf)
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 999, y: 400), screen), .rightHalf)
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 500, y: 0), screen), .fill)
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 500, y: 400), screen), .none)
    }

    func testTheMiddleOfTheScreenSnapsToNothing() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 500, y: 400), visibleFrame: screen)), .none)
    }

    func testSnapFramesTileTheVisibleFrameExactly() {
        let left = DragSnapPolicy.frame(.leftHalf, in: screen)!
        let right = DragSnapPolicy.frame(.rightHalf, in: screen)!
        XCTAssertEqual(left.minX, screen.minX)
        XCTAssertEqual(left.maxX, right.minX)
        XCTAssertEqual(right.maxX, screen.maxX)
        XCTAssertEqual(left.height, screen.height)
        XCTAssertEqual(DragSnapPolicy.frame(.fill, in: screen), screen)
        XCTAssertNil(DragSnapPolicy.frame(.none, in: screen))
    }

    func testAnOddWidthLeavesNoGapBetweenTheHalves() {
        let odd = CGRect(x: 0, y: 0, width: 1001, height: 800)
        XCTAssertEqual(DragSnapPolicy.frame(.leftHalf, in: odd)!.maxX, DragSnapPolicy.frame(.rightHalf, in: odd)!.minX)
        XCTAssertEqual(DragSnapPolicy.frame(.rightHalf, in: odd)!.maxX, odd.maxX)
    }

    // MARK: - Phase 5: quarters and edge-depth thirds

    /// The four 48x48 corner boxes snap to quarters. Screen is 1000x800, so the near-corner reach ends at
    /// x 48/952 and y 48/752.
    func testTheCornersSnapToQuarters() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 10, y: 10), visibleFrame: screen)), .topLeftQuarter)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 990, y: 10), visibleFrame: screen)), .topRightQuarter)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 10, y: 790), visibleFrame: screen)), .bottomLeftQuarter)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 990, y: 790), visibleFrame: screen)), .bottomRightQuarter)
    }

    /// A corner wins over the depth bands and over fill: the very top-left is a quarter, not a half or fill.
    func testACornerWinsOverTheEdgeItShares() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 2, y: 2), visibleFrame: screen)), .topLeftQuarter)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 2, y: 40), visibleFrame: screen)), .topLeftQuarter)
        // just below the corner box, the left edge is a plain half again
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 2, y: 60), visibleFrame: screen)), .leftHalf)
    }

    /// In the mid-height strip, pushing inward from the left edge steps half → third → two-thirds; the bands
    /// are 16pt each (edgeReach 48 / 3).
    func testTheLeftEdgeDepthStepsThroughHalfThirdTwoThirds() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 5, y: 400), visibleFrame: screen)), .leftHalf)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 20, y: 400), visibleFrame: screen)), .leftThird)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 40, y: 400), visibleFrame: screen)), .leftTwoThirds)
        // past the reach the window drags freely again
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 60, y: 400), visibleFrame: screen)), .none)
    }

    func testTheRightEdgeDepthMirrorsTheLeft() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 995, y: 400), visibleFrame: screen)), .rightHalf)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 980, y: 400), visibleFrame: screen)), .rightThird)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 960, y: 400), visibleFrame: screen)), .rightTwoThirds)
    }

    /// The new targets keep the shared-edge dwell: a third on an edge that borders another display waits.
    func testDepthAndCornerTargetsStillRespectSharedEdgeDwell() {
        let third = CGPoint(x: 20, y: 400)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: third, visibleFrame: screen, hasNeighbourLeft: true, dwellElapsed: 0.05)), .none)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: third, visibleFrame: screen, hasNeighbourLeft: true, dwellElapsed: 0.25)), .leftThird)
        // a top-left quarter is shared by the display above as well
        let corner = CGPoint(x: 10, y: 10)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: corner, visibleFrame: screen, hasNeighbourAbove: true, dwellElapsed: 0.05)), .none)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: corner, visibleFrame: screen, hasNeighbourAbove: true, dwellElapsed: 0.25)), .topLeftQuarter)
    }

    func testThirdFramesMatchTheKeyboardLayoutsAndQuartersTileTheScreen() {
        XCTAssertEqual(DragSnapPolicy.frame(.leftThird, in: screen), WindowLayoutGeometry.frame(.leftThird, in: screen))
        XCTAssertEqual(DragSnapPolicy.frame(.rightTwoThirds, in: screen), WindowLayoutGeometry.frame(.rightTwoThirds, in: screen))
        let tl = DragSnapPolicy.frame(.topLeftQuarter, in: screen)!
        let tr = DragSnapPolicy.frame(.topRightQuarter, in: screen)!
        let bl = DragSnapPolicy.frame(.bottomLeftQuarter, in: screen)!
        let br = DragSnapPolicy.frame(.bottomRightQuarter, in: screen)!
        XCTAssertEqual(tl, CGRect(x: 0, y: 0, width: 500, height: 400))
        XCTAssertEqual(tl.maxX, tr.minX)
        XCTAssertEqual(tl.maxY, bl.minY)
        XCTAssertEqual(br.maxX, screen.maxX)
        XCTAssertEqual(br.maxY, screen.maxY)
    }

    func testADegenerateScreenProducesNoTargetAndNoFrame() {
        let empty = CGRect(x: 0, y: 0, width: 0, height: 0)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: .zero, visibleFrame: empty)), .none)
        XCTAssertNil(DragSnapPolicy.frame(.leftHalf, in: empty))
    }

    /// The menubar strip belongs to the screen but not to its visible frame, and the fill edge sits exactly
    /// there. Looking the screen up by visible frame lost the cursor at the top of the screen.
    func testTheScreenIsFoundByItsFullFrameSoTheMenubarStripStillCounts() {
        let screen = DragScreenGeometry(full: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                        visible: CGRect(x: 0, y: 33, width: 1512, height: 949))
        XCTAssertEqual(DragScreenLookup.visibleFrame(containing: CGPoint(x: 700, y: 5), screens: [screen]), screen.visible)
        XCTAssertEqual(DragScreenLookup.visibleFrame(containing: CGPoint(x: 700, y: 500), screens: [screen]), screen.visible)
        XCTAssertNil(DragScreenLookup.visibleFrame(containing: CGPoint(x: 700, y: 2000), screens: [screen]))
    }

    func testACursorInTheMenubarStripStillReportsTheFillEdge() {
        let visible = CGRect(x: 0, y: 33, width: 1512, height: 949)
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 700, y: 5), visible), .fill)
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 700, y: 34), visible), .fill)
        XCTAssertEqual(DragSnapPolicy.edge(CGPoint(x: 700, y: 300), visible), .none)
    }

    func testTheModifierMatchesOnlyItsExactCombination() {
        XCTAssertTrue(DragModifierPreference.commandShift.matches([.command, .shift]))
        XCTAssertFalse(DragModifierPreference.commandShift.matches([.command]))
        XCTAssertFalse(DragModifierPreference.commandShift.matches([.shift]))
        // a stray modifier must not arm a drag the user did not ask for
        XCTAssertFalse(DragModifierPreference.commandShift.matches([.command, .shift, .option]))
        XCTAssertTrue(DragModifierPreference.fn.matches([.function]))
        XCTAssertTrue(DragModifierPreference.commandOption.matches([.command, .option]))
        XCTAssertFalse(DragModifierPreference.commandOption.matches([.command, .option, .shift]))
        XCTAssertTrue(DragModifierPreference.optionShift.matches([.option, .shift]))
        XCTAssertFalse(DragModifierPreference.optionShift.matches([.option]))
    }

    func testAnIrrelevantFlagDoesNotBreakTheMatch() {
        // caps lock and numeric pad are not part of the combination and must be ignored
        XCTAssertTrue(DragModifierPreference.commandShift.matches([.command, .shift, .capsLock]))
    }

    func testTheDisabledModifierNeverMatches() {
        XCTAssertFalse(DragModifierPreference.disabled.matches([]))
        XCTAssertFalse(DragModifierPreference.disabled.matches([.command, .shift]))
        XCTAssertNil(DragModifierPreference.disabled.requiredFlags)
    }

    /// Order matters beyond looks: the preference stores an index into this list. Any change here must
    /// ship with a matching index migration in `PreferencesMigrations.migrateDragModifierIndexes`.
    func testThePickerOrderMatchesTheStoredIndexContract() {
        XCTAssertEqual(DragModifierPreference.selectable, [.disabled, .commandControl, .commandOption, .fn, .commandShift, .optionShift])
        XCTAssertEqual(DragModifierPreference.selectable.first, .disabled)
    }

    func testTheModuleIsOffByDefaultAndOnlyCommandControlNeedsTheGlobalSetting() {
        XCTAssertFalse(DragModifierPreference.disabled.isEnabled)
        XCTAssertTrue(DragModifierPreference.commandControl.requiresWindowDragOnGestureDisabled)
        [DragModifierPreference.disabled, .commandShift, .fn, .commandOption, .optionShift].forEach {
            XCTAssertFalse($0.requiresWindowDragOnGestureDisabled, "\($0)")
        }
    }
}

extension DragSessionTests {
    func testTheStatusItemIsOnlyADropTargetWhereItActuallyIs() {
        let item = CGRect(x: 1400, y: 0, width: 110, height: 24)
        XCTAssertTrue(MenubarDropTarget.isOver(CGPoint(x: 1450, y: 10), statusItemFrame: item))
        XCTAssertFalse(MenubarDropTarget.isOver(CGPoint(x: 1450, y: 40), statusItemFrame: item))
        XCTAssertFalse(MenubarDropTarget.isOver(CGPoint(x: 100, y: 10), statusItemFrame: item))
        XCTAssertFalse(MenubarDropTarget.isOver(CGPoint(x: 1450, y: 10), statusItemFrame: nil))
        XCTAssertFalse(MenubarDropTarget.isOver(.zero, statusItemFrame: .zero))
    }

    /// The strip is 30pt tall and borders the next display, so slipping out of the item on the way to
    /// releasing used to lose the target. It holds while the cursor stays in the menubar band.
    func testTheDropTargetHoldsWhileTheCursorStaysInTheMenubarStrip() {
        XCTAssertTrue(MenubarDropTarget.staysLatched(CGPoint(x: 500, y: 5), menubarStripBottom: 30))
        XCTAssertTrue(MenubarDropTarget.staysLatched(CGPoint(x: 500, y: 29), menubarStripBottom: 30))
        XCTAssertFalse(MenubarDropTarget.staysLatched(CGPoint(x: 500, y: 31), menubarStripBottom: 30))
    }

    /// A window straddling two screens belongs to the one it covers most, not to the one holding its origin.
    func testTheSourceDisplayIsTheOneTheWindowMostlyCovers() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let mostlyRight = CGRect(x: 900, y: 100, width: 600, height: 400)
        XCTAssertEqual(MenubarDropTarget.sourceIndex(of: mostlyRight, in: [left, right]), 1)
        let mostlyLeft = CGRect(x: 700, y: 100, width: 600, height: 400)
        XCTAssertEqual(MenubarDropTarget.sourceIndex(of: mostlyLeft, in: [left, right]), 0)
        XCTAssertNil(MenubarDropTarget.sourceIndex(of: CGRect(x: 5000, y: 0, width: 10, height: 10), in: [left, right]))
    }
}
