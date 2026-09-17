import XCTest

class MenuLayoutTests: XCTestCase {
    private let entries: [MenuEntrySpec] = [
        MenuEntrySpec(id: "settings", group: .settings),
        MenuEntrySpec(id: "show", group: .switcher),
        MenuEntrySpec(id: "isolate", group: .windows),
        MenuEntrySpec(id: "quitAll", group: .apps),
        MenuEntrySpec(id: "pick", group: .tools),
        MenuEntrySpec(id: "cat", group: .toggles),
        MenuEntrySpec(id: "about", group: .app),
        MenuEntrySpec(id: "quit", group: .app),
    ]

    func testOtherGroupsAppearOnceAsSectionsOfOther() {
        let items = MenuLayout.build(entries, headersSupported: true)
        let otherGroups: [MenuGroupEntries] = [MenuGroupEntries(group: .apps, ids: ["quitAll"]), MenuGroupEntries(group: .tools, ids: ["pick"]),
                                               MenuGroupEntries(group: .toggles, ids: ["cat"])]
        let expected: [MenuLayoutItem] = [
            .header(.switcher), .entry("show"), .separator,
            .header(.windows), .entry("isolate"), .separator,
            .other(otherGroups), .separator,
            .entry("settings"), .separator,
            .entry("about"), .entry("quit"),
        ]
        XCTAssertEqual(items, expected)
    }

    func testAnEmptyGroupLeavesNoHeaderOrSeparator() {
        let remaining: [MenuEntrySpec] = entries.filter { $0.group != .windows }
        let items: [MenuLayoutItem] = MenuLayout.build(remaining, headersSupported: true)
        XCTAssertFalse(items.contains(.header(.windows)))
        XCTAssertFalse(hasDoubleSeparator(items))
    }

    private func hasDoubleSeparator(_ items: [MenuLayoutItem]) -> Bool {
        for index in items.indices.dropFirst() where items[index] == .separator && items[index - 1] == .separator {
            return true
        }
        return false
    }

    func testOtherDisappearsWhenAllItsGroupsAreEmpty() {
        let items = MenuLayout.build(entries.filter { !$0.group.isInOther }, headersSupported: true)
        let hasOther = items.contains { item -> Bool in
            guard case .other = item else { return false }
            return true
        }
        XCTAssertFalse(hasOther)
    }

    func testWithoutHeaderSupportOnlySeparatorsRemain() {
        let items = MenuLayout.build(entries, headersSupported: false)
        XCTAssertFalse(items.contains { if case .header = $0 { return true } else { return false } })
        XCTAssertEqual(Array(items.prefix(3)), [.entry("show"), .separator, .entry("isolate")])
    }

    func testNoLeadingOrTrailingSeparator() {
        let items = MenuLayout.build(entries.filter { $0.group == .app }, headersSupported: true)
        let expected: [MenuLayoutItem] = [.entry("about"), .entry("quit")]
        XCTAssertEqual(items, expected)
    }

    func testOnlySwitcherWindowsAndTheAppBlockStayInTheMainMenu() {
        XCTAssertEqual(MenuGroup.allCases.filter { !$0.isInOther }, [.switcher, .windows, .settings, .app])
        XCTAssertFalse(MenuGroup.app.hasHeader)
        XCTAssertFalse(MenuGroup.settings.hasHeader)
        XCTAssertEqual(MenuGroup.allCases.suffix(2), [.settings, .app])
    }

    func testRetiredVisibilityPreferencesAreRecognised() {
        XCTAssertTrue(MenuLayout.isRetiredPreference("menuGroupVisible.tools"))
        XCTAssertTrue(MenuLayout.isRetiredPreference("menuEntryVisible.system.clearClipboard"))
        XCTAssertFalse(MenuLayout.isRetiredPreference("menubarIcon"))
    }

    func testBrowserActionIdsRoundTrip() {
        XCTAssertEqual(DefaultBrowserActionId.bundleId(fromStableId: DefaultBrowserActionId.stableId("org.mozilla.firefox")), "org.mozilla.firefox")
        XCTAssertNil(DefaultBrowserActionId.bundleId(fromStableId: "browser.setDefault."))
        XCTAssertNil(DefaultBrowserActionId.bundleId(fromStableId: "windowFocus.isolate"))
    }

    func testDuplicateBrowserCopiesCollapseToThePreferredOne() {
        let apps: [(bundleId: String?, path: String)] = [
            ("com.microsoft.edgemac", "/Users/x/Library/EdgeUpdater/148/Microsoft Edge.app"),
            ("com.microsoft.edgemac", "/Applications/Microsoft Edge.app"),
            ("org.mozilla.firefox", "/Applications/Firefox.app"),
            (nil, "/Applications/Broken.app"),
        ]
        let unique = DefaultBrowserActionId.uniqueApps(apps) { $0 == "com.microsoft.edgemac" ? "/Applications/Microsoft Edge.app" : nil }
        XCTAssertEqual(unique.map(\.bundleId), ["com.microsoft.edgemac", "org.mozilla.firefox"])
        XCTAssertEqual(unique.map(\.path), ["/Applications/Microsoft Edge.app", "/Applications/Firefox.app"])
    }

    func testAPreferredPathOutsideTheListIsIgnored() {
        let unique = DefaultBrowserActionId.uniqueApps([("a", "/one.app"), ("a", "/two.app")]) { _ in "/elsewhere.app" }
        XCTAssertEqual(unique.map(\.path), ["/one.app"])
    }

    func testOnlyAppsThatAlsoOpenHtmlCountAsBrowsers() {
        let web = ["/Applications/Safari.app", "/Applications/ChatGPT.app", "/Applications/cmux.app"]
        XCTAssertEqual(DefaultBrowserActionId.browserPaths(openingWebLinks: web, openingHtml: ["/Applications/Safari.app", "/Applications/Preview.app"]),
                       ["/Applications/Safari.app"])
    }

    func testSystemActionIdsAreUnique() {
        XCTAssertEqual(Set(SystemAction.allCases.map(\.rawValue)).count, SystemAction.allCases.count)
    }
}
