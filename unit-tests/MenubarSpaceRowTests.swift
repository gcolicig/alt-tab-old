import XCTest

class MenubarSpaceRowTests: XCTestCase {
    private func assertCentered(_ rect: NSRect, in availableHeight: CGFloat, _ message: String = "") {
        XCTAssertEqual(rect.midY, availableHeight / 2, accuracy: 0.001, message)
    }

    func testElementsStayCenteredWhateverTheButtonHeightTurnsOutToBe() {
        [22, 24, 32, 37].map { CGFloat($0) }.forEach { height in
            assertCentered(MenubarSpaceRow.centeredRect(x: 4, width: 20, availableHeight: height, preferredHeight: MenubarSpaceRow.iconHeight), in: height, "icon at \(height)")
            assertCentered(MenubarSpaceRow.centeredRect(x: 0, width: 24, availableHeight: height, preferredHeight: MenubarSpaceRow.segmentHeight), in: height, "segment at \(height)")
            assertCentered(MenubarSpaceRow.centeredRect(x: 0, width: 1, availableHeight: height, preferredHeight: MenubarSpaceRow.dividerHeight), in: height, "divider at \(height)")
        }
    }

    /// The element keeps its optical height instead of growing with the button, so a 22pt and a 33pt
    /// status button put the same sized box in the same place relative to the neighbouring system items.
    func testTheHeightDoesNotFollowTheButton() {
        XCTAssertEqual(MenubarSpaceRow.centeredRect(x: 0, width: 24, availableHeight: 22, preferredHeight: 16).height, 16)
        XCTAssertEqual(MenubarSpaceRow.centeredRect(x: 0, width: 24, availableHeight: 33, preferredHeight: 16).height, 16)
        XCTAssertEqual(MenubarSpaceRow.centeredRect(x: 0, width: 24, availableHeight: 22, preferredHeight: 16).origin.y, 3)
    }

    /// The segments were the tallest thing in the menubar at 17pt; the system shield sits at about 14.
    func testSegmentsStayWithinTheOpticalBandOfSystemStatusItems() {
        XCTAssertLessThanOrEqual(MenubarSpaceRow.segmentHeight, 16)
        XCTAssertLessThanOrEqual(MenubarSpaceRow.dividerHeight, MenubarSpaceRow.segmentHeight)
    }

    func testATinyButtonClipsInsteadOfOverflowing() {
        let rect = MenubarSpaceRow.centeredRect(x: 0, width: 24, availableHeight: 12, preferredHeight: 16)
        XCTAssertEqual(rect.height, 12)
        XCTAssertEqual(rect.origin.y, 0)
        assertCentered(rect, in: 12)
    }

    /// Measured on 2026-08-05: with separate Spaces off, macOS still reports one group per display, and the
    /// externals carry exactly one Space each. Those groups cannot be switched to and are dropped.
    func testSingleSpaceGroupsDisappearWhileTheArrangementSwitchesTogether() {
        XCTAssertEqual(MenubarSpaceRow.visibleGroupIndexes(spaceCounts: [3, 1, 1], separateSpaces: false), [0])
        XCTAssertEqual(MenubarSpaceRow.visibleGroupIndexes(spaceCounts: [1, 4, 1, 2], separateSpaces: false), [1, 3])
    }

    /// With the setting on, a lone Space is a real state indicator: that display switches independently.
    func testEveryGroupSurvivesWhenDisplaysHaveSeparateSpaces() {
        XCTAssertEqual(MenubarSpaceRow.visibleGroupIndexes(spaceCounts: [3, 1, 1], separateSpaces: true), [0, 1, 2])
    }

    /// Hiding everything would leave the row empty and tell the user less than the truth.
    func testAnArrangementWithOneSpaceEverywhereStillShows() {
        XCTAssertEqual(MenubarSpaceRow.visibleGroupIndexes(spaceCounts: [1, 1], separateSpaces: false), [0, 1])
        XCTAssertEqual(MenubarSpaceRow.visibleGroupIndexes(spaceCounts: [1], separateSpaces: false), [0])
    }

    /// A gesture carries no target display, so a group on another screen is out of reach — unless one
    /// gesture switches everything, in which case refusing the click would be a silent no-op.
    func testAClickFromAnotherDisplayOnlyFailsWhenDisplaysSwitchIndependently() {
        XCTAssertFalse(MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: false, separateSpaces: true))
        XCTAssertTrue(MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: true, separateSpaces: true))
        XCTAssertTrue(MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: false, separateSpaces: false))
        XCTAssertTrue(MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: true, separateSpaces: false))
    }

    func testGroupsUpToNineSpacesGetOneSegmentEach() {
        XCTAssertEqual(MenubarSpaceRow.directSegmentCount(1), 1)
        XCTAssertEqual(MenubarSpaceRow.directSegmentCount(9), 9)
        XCTAssertFalse(MenubarSpaceRow.hasOverflow(9))
        XCTAssertEqual(MenubarSpaceRow.overflowIndexes(9), [])
        XCTAssertEqual(MenubarSpaceRow.groupWidth(3), 3 * MenubarSpaceRow.segmentWidth)
    }

    func testOverflowGivesUpOneSlotSoTheGroupNeverGrowsPastNine() {
        XCTAssertTrue(MenubarSpaceRow.hasOverflow(10))
        XCTAssertEqual(MenubarSpaceRow.directSegmentCount(10), 8)
        XCTAssertEqual(MenubarSpaceRow.overflowIndexes(10), [9, 10])
        // 8 direct segments plus the overflow segment: the group stays nine slots wide
        XCTAssertEqual(MenubarSpaceRow.groupWidth(10), 9 * MenubarSpaceRow.segmentWidth)
        XCTAssertEqual(MenubarSpaceRow.groupWidth(40), 9 * MenubarSpaceRow.segmentWidth)
        XCTAssertEqual(MenubarSpaceRow.overflowIndexes(12), [9, 10, 11, 12])
    }

    func testEmptyGroupTakesNoWidth() {
        XCTAssertEqual(MenubarSpaceRow.directSegmentCount(0), 0)
        XCTAssertFalse(MenubarSpaceRow.hasOverflow(0))
        XCTAssertEqual(MenubarSpaceRow.groupWidth(0), 0)
        XCTAssertEqual(MenubarSpaceRow.totalWidth([]), 0)
    }

    func testTotalWidthAddsAGapOnEachSideOfEveryDivider() {
        XCTAssertEqual(MenubarSpaceRow.totalWidth([3]), 3 * MenubarSpaceRow.segmentWidth)
        XCTAssertEqual(MenubarSpaceRow.totalWidth([3, 2]),
                       5 * MenubarSpaceRow.segmentWidth + 2 * MenubarSpaceRow.groupGap)
        XCTAssertEqual(MenubarSpaceRow.totalWidth([3, 2, 4]),
                       9 * MenubarSpaceRow.segmentWidth + 4 * MenubarSpaceRow.groupGap)
    }

    func testDisplaysFollowScreenOrderAndOnlyThoseThatOwnSpaces() {
        let ordered = MenubarSpaceRow.orderedDisplays(screensInOrder: ["left", "middle", "right"],
                                                      displaysWithSpaces: ["right", "left"])
        XCTAssertEqual(ordered, ["left", "right"])
    }

    func testDisplaysWithoutALiveScreenAreAppendedInAStableOrder() {
        let ordered = MenubarSpaceRow.orderedDisplays(screensInOrder: ["live"],
                                                      displaysWithSpaces: ["zzz", "live", "aaa"])
        // the detached ones must not depend on dictionary order, or the row reshuffles between refreshes
        XCTAssertEqual(ordered, ["live", "aaa", "zzz"])
    }

    func testOrderingIsRepeatableForTheSameInput() {
        let displays = ["d4", "d1", "d3", "d2"]
        let first = MenubarSpaceRow.orderedDisplays(screensInOrder: [], displaysWithSpaces: displays)
        let second = MenubarSpaceRow.orderedDisplays(screensInOrder: [], displaysWithSpaces: displays.reversed())
        XCTAssertEqual(first, second)
    }

    func testADisplayListedTwiceProducesOneGroup() {
        let ordered = MenubarSpaceRow.orderedDisplays(screensInOrder: ["dup", "dup"], displaysWithSpaces: ["dup"])
        XCTAssertEqual(ordered, ["dup"])
    }
}
