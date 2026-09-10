import XCTest

final class ScrollWheelPolicyTests: XCTestCase {
    func testNothingIsTouchedWhileBothReasonsAreOff() {
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: true, absorbContinuous: false, rewriteDiscrete: false), .passThrough)
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: false, absorbContinuous: false, rewriteDiscrete: false), .passThrough)
    }

    func testSwitcherGestureSwallowsContinuousScrollingOnly() {
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: true, absorbContinuous: true, rewriteDiscrete: false), .block)
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: false, absorbContinuous: true, rewriteDiscrete: false), .passThrough)
    }

    func testDirectionRewritesDiscreteScrollingOnly() {
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: false, absorbContinuous: false, rewriteDiscrete: true), .invertVertical)
        // the trackpad keeps following the system's Natural Scrolling preference
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: true, absorbContinuous: false, rewriteDiscrete: true), .passThrough)
    }

    /// Both reasons hold during a switcher gesture with the setting on. Absorbing wins for continuous
    /// events; a wheel notch is still mirrored, so the direction does not change for the length of a
    /// gesture and back again.
    func testBothReasonsTogetherKeepEachOthersBehaviour() {
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: true, absorbContinuous: true, rewriteDiscrete: true), .block)
        XCTAssertEqual(ScrollWheelPolicy.verdict(isContinuous: false, absorbContinuous: true, rewriteDiscrete: true), .invertVertical)
    }
}
