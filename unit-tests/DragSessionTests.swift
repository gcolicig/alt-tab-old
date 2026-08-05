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

    /// Order matters beyond looks: the preference stores an index into this list, so appending is the only
    /// safe way to add a modifier without repointing everybody's stored choice.
    func testThePickerStartsDisabledAndOnlyGrowsAtTheEnd() {
        XCTAssertEqual(DragModifierPreference.selectable, [.disabled, .commandShift, .fn, .commandControl])
        XCTAssertEqual(DragModifierPreference.selectable.first, .disabled)
        XCTAssertEqual(DragModifierPreference.selectable.firstIndex(of: .commandShift), 1)
        XCTAssertEqual(DragModifierPreference.selectable.firstIndex(of: .fn), 2)
    }

    func testTheModuleIsOffByDefaultAndOnlyCommandControlNeedsTheGlobalSetting() {
        XCTAssertFalse(DragModifierPreference.disabled.isEnabled)
        XCTAssertTrue(DragModifierPreference.commandControl.requiresWindowDragOnGestureDisabled)
        [DragModifierPreference.disabled, .commandShift, .fn].forEach {
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
