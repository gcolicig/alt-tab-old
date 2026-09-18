import XCTest

class PreferencesResetTests: XCTestCase {
    func testKnownKeysAreKeptForReset() {
        let known: Set<String> = ["startAtLogin", "menubarIcon"]
        XCTAssertEqual(PreferencesResetLogic.resettableKeys(requested: ["startAtLogin"], knownDefaultKeys: known), ["startAtLogin"])
    }

    func testUnknownKeysAreDropped() {
        let known: Set<String> = ["startAtLogin"]
        XCTAssertEqual(PreferencesResetLogic.resettableKeys(requested: ["someUnknownKey"], knownDefaultKeys: known), [])
    }

    func testAMixOfKnownAndUnknownKeysKeepsOnlyTheKnownOnes() {
        let known: Set<String> = ["startAtLogin", "menubarIcon"]
        let result = PreferencesResetLogic.resettableKeys(requested: ["startAtLogin", "bogus", "menubarIcon"], knownDefaultKeys: known)
        XCTAssertEqual(result, ["startAtLogin", "menubarIcon"])
    }

    func testEmptyRequestReturnsEmpty() {
        XCTAssertEqual(PreferencesResetLogic.resettableKeys(requested: [], knownDefaultKeys: ["startAtLogin"]), [])
    }

    func testKeysWithPrefixReturnsOnlyMatchingKeysSorted() {
        let defaults: [String: Any] = ["leaderSlotAction1": "", "leaderSlotAction0": "", "leaderSlotKeys0": "", "startAtLogin": "true"]
        XCTAssertEqual(PreferencesResetLogic.keysWithPrefix("leaderSlotAction", in: defaults), ["leaderSlotAction0", "leaderSlotAction1"])
    }

    func testKeysWithPrefixReturnsEmptyWhenNothingMatches() {
        let defaults: [String: Any] = ["startAtLogin": "true", "menubarIcon": "0"]
        XCTAssertEqual(PreferencesResetLogic.keysWithPrefix("flickRing", in: defaults), [])
    }

    func testKeysWithPrefixDoesNotMatchAnUnrelatedKeyContainingThePrefix() {
        let defaults: [String: Any] = ["flickRingButton": "3", "flickRingUp": "", "otherFlickRingButtonNote": ""]
        // hasPrefix only matches a leading substring, so "otherFlickRingButtonNote" (prefix elsewhere) is excluded
        XCTAssertEqual(PreferencesResetLogic.keysWithPrefix("flickRing", in: defaults), ["flickRingButton", "flickRingUp"])
    }
}
