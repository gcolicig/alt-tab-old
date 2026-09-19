import XCTest

class SlotListTests: XCTestCase {
    func testOccupiedSlotsIgnoreBlanks() {
        let values: [String] = ["com.apple.Safari", "", "  ", "github.com", "\n"]
        XCTAssertEqual(SlotList.occupied(values), [0, 3])
        XCTAssertEqual(SlotList.firstFree(values), 1)
    }

    func testAFullListHasNoFreeSlot() {
        let values: [String] = ["a", "b"]
        XCTAssertNil(SlotList.firstFree(values))
    }

    func testOnlyWhitespaceSlotsNeedCleanup() {
        XCTAssertTrue(SlotList.needsCleanup("  "))
        XCTAssertFalse(SlotList.needsCleanup(""))
        XCTAssertFalse(SlotList.needsCleanup("a"))
    }

    func testAddingBundleIdsKeepsOrderAndSkipsDuplicates() {
        XCTAssertEqual(SlotList.addingBundleIds("a\nb", ["b", "c"]), "a\nb\nc")
        XCTAssertEqual(SlotList.addingBundleIds("", ["x"]), "x")
        XCTAssertEqual(SlotList.addingBundleIds("a, b", []), "a\nb")
    }

    func testRemovingABundleId() {
        XCTAssertEqual(SlotList.removingBundleId("a\nb\nc", "b"), "a\nc")
        XCTAssertEqual(SlotList.removingBundleId("a", "a"), "")
    }
}
