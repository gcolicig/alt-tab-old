import XCTest
import ShortcutRecorder

final class ShortcutDefaultTests: XCTestCase {
    func testBothUnassignedIsNotADifference() {
        XCTAssertFalse(ShortcutDefault.differsFromDefault(nil, nil))
    }

    func testClearingAnAssignedDefaultIsADifference() {
        XCTAssertTrue(ShortcutDefault.differsFromDefault(nil, Shortcut(keyEquivalent: "⇧")))
    }

    func testAssigningOverAnUnassignedDefaultIsADifference() {
        XCTAssertTrue(ShortcutDefault.differsFromDefault(Shortcut(keyEquivalent: "⇧"), nil))
    }

    func testTheSameCombinationIsNotADifference() {
        XCTAssertFalse(ShortcutDefault.differsFromDefault(Shortcut(keyEquivalent: "⇧"), Shortcut(keyEquivalent: "⇧")))
    }

    func testADifferentCombinationIsADifference() {
        XCTAssertTrue(ShortcutDefault.differsFromDefault(Shortcut(keyEquivalent: "⌘⇧"), Shortcut(keyEquivalent: "⇧")))
    }
}
