import XCTest

final class ScrollTransformTests: XCTestCase {
    func testContinuousUsesTheTrackpadSettingsAndDiscreteTheMouse() {
        let mouse = ScrollAxisSettings(reverseVertical: true, speed: 2)
        let trackpad = ScrollAxisSettings(reverseVertical: false, speed: 0.5)
        XCTAssertEqual(ScrollTransform.settings(isContinuous: true, mouse: mouse, trackpad: trackpad), trackpad)
        XCTAssertEqual(ScrollTransform.settings(isContinuous: false, mouse: mouse, trackpad: trackpad), mouse)
    }

    func testReverseFlipsTheVerticalSignAndSpeedScales() {
        XCTAssertEqual(ScrollTransform.verticalFactor(ScrollAxisSettings(reverseVertical: true, speed: 1)), -1)
        XCTAssertEqual(ScrollTransform.verticalFactor(ScrollAxisSettings(reverseVertical: false, speed: 2)), 2)
        XCTAssertEqual(ScrollTransform.verticalFactor(ScrollAxisSettings(reverseVertical: true, speed: 3)), -3)
    }

    /// The MVP reverses the vertical axis only; horizontal keeps its direction and just scales.
    func testHorizontalIsNeverReversedOnlyScaled() {
        XCTAssertEqual(ScrollTransform.horizontalFactor(ScrollAxisSettings(reverseVertical: true, speed: 2)), 2)
        XCTAssertEqual(ScrollTransform.horizontalFactor(ScrollAxisSettings(reverseVertical: false, speed: 0.5)), 0.5)
    }

    /// The default (no reverse, 1× speed) is a no-op, so the tap can leave the event untouched and need not
    /// run at all.
    func testTheNeutralSettingModifiesNothing() {
        XCTAssertFalse(ScrollTransform.modifies(ScrollAxisSettings()))
        XCTAssertTrue(ScrollTransform.modifies(ScrollAxisSettings(reverseVertical: true, speed: 1)))
        XCTAssertTrue(ScrollTransform.modifies(ScrollAxisSettings(reverseVertical: false, speed: 2)))
        XCTAssertFalse(ScrollTransform.anyModifies(mouse: ScrollAxisSettings(), trackpad: ScrollAxisSettings()))
        XCTAssertTrue(ScrollTransform.anyModifies(mouse: ScrollAxisSettings(), trackpad: ScrollAxisSettings(reverseVertical: true)))
    }

    func testSpeedFactorsAreStable() {
        XCTAssertEqual(ScrollSpeedPreference.allCases.map { $0.factor }, [0.5, 1.0, 2.0, 3.0, 4.0, 5.0])
        XCTAssertEqual(ScrollSpeedPreference.normal.factor, 1.0)
    }
}
