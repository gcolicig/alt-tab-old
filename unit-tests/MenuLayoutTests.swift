import XCTest

class MenuLayoutTests: XCTestCase {
    private let entries = [
        MenuEntrySpec(id: "show", group: .switcher),
        MenuEntrySpec(id: "isolate", group: .windows),
        MenuEntrySpec(id: "quitAll", group: .apps),
        MenuEntrySpec(id: "pick", group: .tools),
        MenuEntrySpec(id: "cat", group: .toggles),
        MenuEntrySpec(id: "settings", group: .app),
        MenuEntrySpec(id: "quit", group: .app),
    ]

    func testOtherGroupsAppearOnceAsSectionsOfOther() {
        let items = MenuLayout.build(entries, headersSupported: true)
        XCTAssertEqual(items, [
            .header(.switcher), .entry("show"), .separator,
            .header(.windows), .entry("isolate"), .separator,
            .other([MenuGroupEntries(group: .apps, ids: ["quitAll"]), MenuGroupEntries(group: .tools, ids: ["pick"]),
                    MenuGroupEntries(group: .toggles, ids: ["cat"])]), .separator,
            .entry("settings"), .entry("quit"),
        ])
    }

    func testAnEmptyGroupLeavesNoHeaderOrSeparator() {
        let items = MenuLayout.build(entries.filter { $0.group != .windows }, headersSupported: true)
        XCTAssertFalse(items.contains(.header(.windows)))
        XCTAssertFalse(zip(items, items.dropFirst()).contains { $0 == .separator && $1 == .separator })
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
        XCTAssertEqual(items.first, .entry("show"))
    }

    func testNoLeadingOrTrailingSeparator() {
        let items = MenuLayout.build(entries.filter { $0.group == .app }, headersSupported: true)
        XCTAssertEqual(items, [.entry("settings"), .entry("quit")])
    }

    func testOnlySwitcherWindowsAndTheAppBlockStayInTheMainMenu() {
        XCTAssertEqual(MenuGroup.allCases.filter { !$0.isInOther }, [.switcher, .windows, .app])
        XCTAssertFalse(MenuGroup.app.hasHeader)
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
