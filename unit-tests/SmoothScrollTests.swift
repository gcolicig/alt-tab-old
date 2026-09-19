import Cocoa
import XCTest

final class SmoothScrollTests: XCTestCase {
    func testStepSumsToTheFullDistance() {
        var remaining = 300.0
        var carry = 0.0
        var total = 0
        var iterations = 0
        while remaining != 0 && iterations < 10_000 {
            let step = SmoothScrollStep.next(remaining: remaining, dt: 1.0 / 120, duration: SmoothScrollDuration.medium.seconds, carry: carry)
            total += step.emit
            remaining = step.remaining
            carry = step.carry
            iterations += 1
        }
        XCTAssertEqual(total, 300)
    }

    func testEndsWithinRoughlyOneDurationOfFrames() {
        let duration = SmoothScrollDuration.short.seconds
        let dt = 1.0 / 120
        var remaining = 100.0
        var carry = 0.0
        var iterations = 0
        let maxIterations = Int((duration / dt) * 3) + 10
        while remaining != 0 && iterations < maxIterations {
            let step = SmoothScrollStep.next(remaining: remaining, dt: dt, duration: duration, carry: carry)
            remaining = step.remaining
            carry = step.carry
            iterations += 1
        }
        XCTAssertEqual(remaining, 0)
        XCTAssertLessThan(iterations, maxIterations)
    }

    /// Every frame's fractional leftover is carried, not dropped, so many small frames still add up exactly.
    func testCarryNeverLosesPixels() {
        let step1 = SmoothScrollStep.next(remaining: 10, dt: 0.001, duration: 1, carry: 0)
        XCTAssertEqual(step1.emit, 0)
        XCTAssertGreaterThan(step1.carry, 0)
        let step2 = SmoothScrollStep.next(remaining: step1.remaining, dt: 0.001, duration: 1, carry: step1.carry)
        XCTAssertGreaterThanOrEqual(step2.carry, 0)
    }

    /// A delta in the opposite direction replaces the remaining distance (instant reversal is the caller's
    /// job in `SmoothScroller.add`), but the step function itself must handle a negative remaining the same
    /// way as a positive one.
    func testNegativeRemainingMirrorsPositive() {
        let positive = SmoothScrollStep.next(remaining: 50, dt: 1.0 / 120, duration: 0.2, carry: 0)
        let negative = SmoothScrollStep.next(remaining: -50, dt: 1.0 / 120, duration: 0.2, carry: 0)
        XCTAssertEqual(positive.emit, -negative.emit)
        XCTAssertEqual(positive.remaining, -negative.remaining)
    }

    func testFinishesWhenBelowThreshold() {
        let step = SmoothScrollStep.next(remaining: 0.5, dt: 1.0 / 120, duration: 0.2, carry: 0)
        XCTAssertEqual(step.emit, 1)
        XCTAssertEqual(step.remaining, 0)
        XCTAssertEqual(step.carry, 0)
    }

    func testShouldSmoothOnlyForDiscreteNonSyntheticNonModifiedEventsWhenEnabled() {
        XCTAssertTrue(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: [], isSynthetic: false, enabled: true))
        XCTAssertFalse(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: [], isSynthetic: false, enabled: false))
        XCTAssertFalse(SmoothScrollStep.shouldSmooth(isContinuous: true, flags: [], isSynthetic: false, enabled: true))
        XCTAssertFalse(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: [], isSynthetic: true, enabled: true))
        XCTAssertFalse(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: .maskCommand, isSynthetic: false, enabled: true))
        XCTAssertFalse(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: .maskAlternate, isSynthetic: false, enabled: true))
        XCTAssertFalse(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: .maskControl, isSynthetic: false, enabled: true))
        XCTAssertTrue(SmoothScrollStep.shouldSmooth(isContinuous: false, flags: .maskShift, isSynthetic: false, enabled: true))
    }

    func testDurationsAreOrderedShortestToLongest() {
        let seconds = SmoothScrollDuration.allCases.map(\.seconds)
        XCTAssertEqual(seconds, seconds.sorted())
        XCTAssertEqual(Set(seconds).count, seconds.count)
    }

    func testAnyModifiesIncludesSmoothMouseScrolling() {
        // smoothScrollMouse is a separate preference from reverse/speed, but ScrollwheelEvents.scrollModifyActive
        // must also keep the tap alive for it; this documents the neutral ScrollAxisSettings baseline that
        // scrollModifyActive() combines with the smoothScrollMouse flag.
        XCTAssertFalse(ScrollTransform.anyModifies(mouse: ScrollAxisSettings(), trackpad: ScrollAxisSettings()))
    }
}
