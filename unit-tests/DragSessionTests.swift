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

    func testTheTopEdgeFillsAndTheBottomEdgeIsInert() {
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 500, y: 799), visibleFrame: screen)), .fill)
        XCTAssertEqual(DragSnapPolicy.target(DragSnapContext(cursor: CGPoint(x: 500, y: 0), visibleFrame: screen)), .none)
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

    func testTheModuleIsOffByDefaultAndOnlyCommandControlNeedsTheGlobalSetting() {
        XCTAssertFalse(DragModifierPreference.disabled.isEnabled)
        XCTAssertTrue(DragModifierPreference.commandControl.requiresWindowDragOnGestureDisabled)
        [DragModifierPreference.disabled, .commandShift, .fn].forEach {
            XCTAssertFalse($0.requiresWindowDragOnGestureDisabled, "\($0)")
        }
    }
}
