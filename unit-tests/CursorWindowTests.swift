import XCTest

final class CursorWindowTests: XCTestCase {
    func testTheElementUnderTheCursorWinsOverEveryFallback() {
        let candidates = CursorWindowCandidates(elementWindow: 7, focusedWindow: 9, boundsMatches: [11])
        XCTAssertEqual(CursorWindowResolutionPolicy.resolve(candidates), .resolved(7))
    }

    func testTheFocusedWindowIsUsedOnlyWhenTheElementStageFailed() {
        XCTAssertEqual(CursorWindowResolutionPolicy.resolve(CursorWindowCandidates(focusedWindow: 9, boundsMatches: [11])), .resolved(9))
    }

    func testAUniqueBoundsMatchIsAcceptedButAnAmbiguousOneIsRefused() {
        XCTAssertEqual(CursorWindowResolutionPolicy.resolve(CursorWindowCandidates(boundsMatches: [11])), .resolved(11))
        XCTAssertEqual(CursorWindowResolutionPolicy.resolve(CursorWindowCandidates(boundsMatches: [11, 12])), .refused(.ambiguousBoundsMatch))
    }

    func testNoCandidateAtAllRefusesRatherThanGuessing() {
        XCTAssertEqual(CursorWindowResolutionPolicy.resolve(CursorWindowCandidates()), .refused(.nothingUnderCursor))
    }

    /// A synchronous AX query into our own process has to be answered by the very thread that is waiting
    /// for the answer, so it deadlocks. The switcher path already excludes us; the cursor path must too.
    func testOurOwnProcessIsRefusedBeforeAnyFurtherQuery() {
        XCTAssertTrue(CursorWindowOwnProcess.shouldRefuse(hitPid: 42, ownPid: 42))
        XCTAssertFalse(CursorWindowOwnProcess.shouldRefuse(hitPid: 43, ownPid: 42))
    }

    private func rect(_ x: CGFloat) -> CGRect {
        CGRect(x: x, y: 0, width: 100, height: 100)
    }

    func testTheFirstSubmitWritesImmediately() {
        var coalescer = AxWriteCoalescer(minimumInterval: 0.016)
        XCTAssertEqual(coalescer.submit(rect(1), now: 0), rect(1))
        XCTAssertEqual(coalescer.inFlight, rect(1))
    }

    func testASubmitWhileAWriteIsOutstandingIsHeldNotQueued() {
        var coalescer = AxWriteCoalescer(minimumInterval: 0.016)
        _ = coalescer.submit(rect(1), now: 0)
        XCTAssertNil(coalescer.submit(rect(2), now: 0.1))
        XCTAssertNil(coalescer.submit(rect(3), now: 0.2))
        // only the newest survives: intermediate frames are dropped, not stacked
        XCTAssertEqual(coalescer.pending, rect(3))
        XCTAssertEqual(coalescer.completed(now: 0.3), rect(3))
    }

    func testCompletionWithNothingPendingWritesNothing() {
        var coalescer = AxWriteCoalescer(minimumInterval: 0.016)
        _ = coalescer.submit(rect(1), now: 0)
        XCTAssertNil(coalescer.completed(now: 0.1))
        XCTAssertNil(coalescer.inFlight)
    }

    func testTheRateLimitHoldsASubmitThatArrivesTooSoon() {
        var coalescer = AxWriteCoalescer(minimumInterval: 0.016)
        _ = coalescer.submit(rect(1), now: 0)
        _ = coalescer.completed(now: 0.001)
        XCTAssertNil(coalescer.submit(rect(2), now: 0.002))
        XCTAssertEqual(coalescer.submit(rect(3), now: 0.5), rect(3))
    }

    /// Without the flush, a drag that ends while a frame is held leaves the window one step behind the
    /// position the user actually released at.
    func testFlushWritesTheHeldFrameIgnoringTheRateLimit() {
        var coalescer = AxWriteCoalescer(minimumInterval: 0.016)
        _ = coalescer.submit(rect(1), now: 0)
        _ = coalescer.completed(now: 0.001)
        XCTAssertNil(coalescer.submit(rect(2), now: 0.002))
        XCTAssertEqual(coalescer.flush(now: 0.003), rect(2))
    }

    func testFlushDoesNothingWhileAWriteIsStillOutstanding() {
        var coalescer = AxWriteCoalescer(minimumInterval: 0.016)
        _ = coalescer.submit(rect(1), now: 0)
        _ = coalescer.submit(rect(2), now: 0.001)
        XCTAssertNil(coalescer.flush(now: 0.002))
    }

    private func entry(_ proposed: CGRect, _ result: CGRect?) -> AxDiagnosticEntry {
        AxDiagnosticEntry(windowId: 1, bundleId: "com.example.app", displayIndex: 0, proposed: proposed, result: result)
    }

    func testTheRingKeepsOnlyTheMostRecentEntries() {
        var ring = AxDiagnosticsRing(capacity: 3)
        (1...5).forEach { ring.record(entry(rect(CGFloat($0)), rect(CGFloat($0)))) }
        XCTAssertEqual(ring.entries.count, 3)
        XCTAssertEqual(ring.entries.first?.proposed, rect(3))
        XCTAssertEqual(ring.entries.last?.proposed, rect(5))
    }

    func testDeviationsSurfaceClampedAndFailedWrites() {
        var ring = AxDiagnosticsRing(capacity: 10)
        ring.record(entry(rect(1), rect(1)))
        ring.record(entry(rect(2), rect(9)))
        ring.record(entry(rect(3), nil))
        XCTAssertEqual(ring.deviations.count, 2)
        XCTAssertFalse(ring.deviations[0].wasHonored)
        XCTAssertNil(ring.deviations[1].result)
    }
}
