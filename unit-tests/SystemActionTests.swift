import XCTest

class SystemActionTests: XCTestCase {
    func testQuitPromptListsNamesUpToTheLimit() {
        XCTAssertEqual(QuitPrompt.names(["A", "B"], limit: 3), "A, B")
        XCTAssertEqual(QuitPrompt.names(["A", "B", "C", "D"], limit: 2), "A, B and 2 more")
    }

    func testShortcutKeysAreUniqueAndEndInShortcut() {
        let keys = SystemAction.allCases.map(\.shortcutPreferenceKey)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertTrue(keys.allSatisfy { $0.hasSuffix("_Shortcut") && !$0.contains(".") })
    }

    func testAutoQuitOnlyListedMode() {
        let rules = AutoQuitRules(mode: .onlyListed, bundleIds: ["com.example.a"])
        XCTAssertTrue(AutoQuitPolicy.applies("com.example.a", rules: rules, isRegular: true, isSelf: false))
        XCTAssertFalse(AutoQuitPolicy.applies("com.example.b", rules: rules, isRegular: true, isSelf: false))
    }

    func testAutoQuitAllExceptListedMode() {
        let rules = AutoQuitRules(mode: .allExceptListed, bundleIds: ["com.example.a"])
        XCTAssertFalse(AutoQuitPolicy.applies("com.example.a", rules: rules, isRegular: true, isSelf: false))
        XCTAssertTrue(AutoQuitPolicy.applies("com.example.b", rules: rules, isRegular: true, isSelf: false))
    }

    func testAutoQuitNeverTouchesFinderSelfOrAgents() {
        let rules = AutoQuitRules(mode: .allExceptListed, bundleIds: [])
        XCTAssertFalse(AutoQuitPolicy.applies("com.apple.finder", rules: rules, isRegular: true, isSelf: false))
        XCTAssertFalse(AutoQuitPolicy.applies("com.example.b", rules: rules, isRegular: true, isSelf: true))
        XCTAssertFalse(AutoQuitPolicy.applies("com.example.b", rules: rules, isRegular: false, isSelf: false))
        XCTAssertFalse(AutoQuitPolicy.applies(nil, rules: rules, isRegular: true, isSelf: false))
    }

    func testAutoQuitRecheckCancelsOnNewWindowOrFocus() {
        XCTAssertTrue(AutoQuitPolicy.shouldQuitNow(hasWindows: false, isFrontmost: false, isTerminated: false, hasMenuBarItems: false))
        XCTAssertFalse(AutoQuitPolicy.shouldQuitNow(hasWindows: true, isFrontmost: false, isTerminated: false, hasMenuBarItems: false))
        XCTAssertFalse(AutoQuitPolicy.shouldQuitNow(hasWindows: false, isFrontmost: true, isTerminated: false, hasMenuBarItems: false))
    }

    func testAutoQuitTreatsOrderedOutWindowsAsClosed() {
        // Music and Cisco Secure Client after the red button: no Space, off screen
        XCTAssertFalse(AutoQuitPolicy.windowCountsAsOpen(isMinimized: false, appIsHidden: false, isOnAnySpace: false, isOnScreen: { false }))
        // a minimized window keeps its Space (Ollama, Bitwarden)
        XCTAssertTrue(AutoQuitPolicy.windowCountsAsOpen(isMinimized: true, appIsHidden: false, isOnAnySpace: true, isOnScreen: { false }))
        XCTAssertTrue(AutoQuitPolicy.windowCountsAsOpen(isMinimized: true, appIsHidden: false, isOnAnySpace: false, isOnScreen: { false }))
        // a hidden app keeps its windows
        XCTAssertTrue(AutoQuitPolicy.windowCountsAsOpen(isMinimized: false, appIsHidden: true, isOnAnySpace: false, isOnScreen: { false }))
        // Trello orders out but keeps its Space: still open
        XCTAssertTrue(AutoQuitPolicy.windowCountsAsOpen(isMinimized: false, appIsHidden: false, isOnAnySpace: true, isOnScreen: { false }))
        XCTAssertTrue(AutoQuitPolicy.windowCountsAsOpen(isMinimized: false, appIsHidden: false, isOnAnySpace: false, isOnScreen: { true }))
    }

    func testAutoQuitSparesAppsWithMenuBarItems() {
        XCTAssertFalse(AutoQuitPolicy.shouldQuitNow(hasWindows: false, isFrontmost: false, isTerminated: false, hasMenuBarItems: true))
        // the user's own exception list overrides the menu bar item, and nothing else
        XCTAssertTrue(AutoQuitPolicy.shouldQuitNow(hasWindows: false, isFrontmost: false, isTerminated: false, hasMenuBarItems: true, quitsDespiteMenuBarItem: true))
        XCTAssertFalse(AutoQuitPolicy.shouldQuitNow(hasWindows: false, isFrontmost: true, isTerminated: false, hasMenuBarItems: true, quitsDespiteMenuBarItem: true))
    }

    func testAutoQuitListRoundTripsAndToleratesGarbage() {
        XCTAssertEqual(AutoQuitPolicy.decodeList(AutoQuitPolicy.encodeList(["a", "b"])), ["a", "b"])
        XCTAssertEqual(AutoQuitPolicy.decodeList("not json"), [])
    }

    func testUnlockWordEndsCatMode() {
        var matcher = UnlockSequenceMatcher()
        XCTAssertFalse("unloc".map { matcher.feed($0) }.contains(true))
        XCTAssertTrue(matcher.feed("k"))
    }

    func testUnlockRestartsOnAWrongKey() {
        var matcher = UnlockSequenceMatcher()
        XCTAssertFalse("unlxock".map { matcher.feed($0) }.contains(true))
        XCTAssertTrue("uuNLOCK".map { matcher.feed($0) }.contains(true))
    }

    func testEmergencyShortcutNeedsAllFourModifiers() {
        XCTAssertTrue(CatModePanic.isEmergencyShortcut(keyCode: 53, flags: CatModePanic.requiredFlags))
        XCTAssertFalse(CatModePanic.isEmergencyShortcut(keyCode: 53, flags: (1 << 17) | (1 << 18)))
        XCTAssertFalse(CatModePanic.isEmergencyShortcut(keyCode: 12, flags: CatModePanic.requiredFlags))
    }
}

class ScreenToolsFormatTests: XCTestCase {
    func testHexIsUppercaseAndClamped() {
        XCTAssertEqual(ScreenToolsFormat.hex(red: 1, green: 0.5, blue: 0), "#FF8000")
        XCTAssertEqual(ScreenToolsFormat.hex(red: 2, green: -1, blue: 0.0039), "#FF0001")
    }

    func testOnlyWebAndMailLinksAreOpenable() {
        XCTAssertNotNil(ScreenToolsFormat.openableUrl(" https://example.com "))
        XCTAssertNotNil(ScreenToolsFormat.openableUrl("mailto:a@example.com"))
        XCTAssertNil(ScreenToolsFormat.openableUrl("file:///etc/passwd"))
        XCTAssertNil(ScreenToolsFormat.openableUrl("WIFI:S:home;T:WPA;P:secret;;"))
    }

    func testLinesAreTrimmedAndBlankLinesDropped() {
        XCTAssertEqual(ScreenToolsFormat.joinLines([" a ", "", "b"]), "a\nb")
    }

    func testSelectionNormalisesDirectionAndRejectsClicks() {
        XCTAssertEqual(ScreenToolsFormat.selection(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 10, y: 20)), CGRect(x: 10, y: 20, width: 40, height: 30))
        XCTAssertNil(ScreenToolsFormat.selection(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 6, y: 6)))
    }

    private let src = MicKeyMapping.sourceKey
    private let dst = MicKeyMapping.destinationKey

    func testMicKeyMappingIsAddedOnceAndKeepsOtherMappings() {
        let capsToEscape: [String: UInt64] = [src: 0x700000039, dst: 0x700000029]
        let once = MicKeyMapping.adding([capsToEscape])
        XCTAssertEqual(once, [capsToEscape, [src: MicKeyMapping.microphoneKey, dst: MicKeyMapping.f17]])
        XCTAssertEqual(MicKeyMapping.adding(once), once)
    }

    func testAnEarlierMicKeyMappingIsReplaced() {
        let toF5: [String: UInt64] = [src: MicKeyMapping.microphoneKey, dst: 0x70000003E]
        XCTAssertEqual(MicKeyMapping.adding([toF5]), [[src: MicKeyMapping.microphoneKey, dst: MicKeyMapping.f17]])
    }

    func testRemovingKeepsMappingsAltTabDidNotMake() {
        let toF5: [String: UInt64] = [src: MicKeyMapping.microphoneKey, dst: 0x70000003E]
        let ours: [String: UInt64] = [src: MicKeyMapping.microphoneKey, dst: MicKeyMapping.f17]
        XCTAssertEqual(MicKeyMapping.removing([toF5, ours]), [toF5])
        XCTAssertEqual(MicKeyMapping.removing([]), [])
    }
}
