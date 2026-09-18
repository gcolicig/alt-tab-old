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
}
