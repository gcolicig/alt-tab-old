import XCTest

class MenubarSpaceRowTests: XCTestCase {
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
