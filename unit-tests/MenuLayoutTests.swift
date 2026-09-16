import XCTest

class MenuLayoutTests: XCTestCase {
    private let entries = [
        MenuEntrySpec(id: "show", group: .switcher),
        MenuEntrySpec(id: "isolate", group: .windows),
        MenuEntrySpec(id: "pick", group: .tools),
        MenuEntrySpec(id: "cat", group: .toggles),
        MenuEntrySpec(id: "settings", group: .app),
        MenuEntrySpec(id: "quit", group: .app),
    ]

    func testGroupsAreSeparatedAndHeadedInOrder() {
        let items = MenuLayout.build(entries, headersSupported: true) { _ in true }
        XCTAssertEqual(items, [
            .header(.switcher), .entry("show"), .separator,
            .header(.windows), .entry("isolate"), .separator,
            .otherTools([MenuGroupEntries(group: .tools, ids: ["pick"]), MenuGroupEntries(group: .toggles, ids: ["cat"])]), .separator,
            .entry("settings"), .entry("quit"),
        ])
    }

    func testAnEmptyGroupLeavesNoHeaderOrSeparator() {
        let items = MenuLayout.build(entries, headersSupported: true) { $0.group != .windows }
        XCTAssertFalse(items.contains(.header(.windows)))
        XCTAssertFalse(zip(items, items.dropFirst()).contains { $0 == .separator && $1 == .separator })
    }

    func testOtherToolsKeepsOnlyNonEmptyGroupsAndVanishesWhenAllAreEmpty() {
        let onlyTools = MenuLayout.build(entries, headersSupported: true) { $0.group != .toggles }
        XCTAssertTrue(onlyTools.contains(.otherTools([MenuGroupEntries(group: .tools, ids: ["pick"])])))
        let hidden: Set<MenuGroup> = [.tools, .toggles]
        let none = MenuLayout.build(entries, headersSupported: true) { !hidden.contains($0.group) }
        let hasOtherTools = none.contains { item -> Bool in
            guard case .otherTools = item else { return false }
            return true
        }
        XCTAssertFalse(hasOtherTools)
    }

    func testWithoutHeaderSupportOnlySeparatorsRemain() {
        let items = MenuLayout.build(entries, headersSupported: false) { _ in true }
        XCTAssertFalse(items.contains { if case .header = $0 { return true } else { return false } })
        XCTAssertEqual(items.first, .entry("show"))
    }

    func testNoLeadingOrTrailingSeparator() {
        let items = MenuLayout.build(entries, headersSupported: true) { $0.group == .app }
        XCTAssertEqual(items, [.entry("settings"), .entry("quit")])
    }

    func testDefaultVisibilityKeepsTheMenuShort() {
        let visible = MenuGroup.allCases.filter(\.visibleByDefault)
        XCTAssertEqual(visible, [.switcher, .windows, .app])
        XCTAssertFalse(MenuGroup.app.canBeHidden)
        XCTAssertFalse(MenuGroup.tools.canBeHidden)
        XCTAssertFalse(MenuGroup.tools.hasHeader)
        XCTAssertEqual(MenuGroup.allCases.filter(\.isInOther), [.tools, .toggles, .defaults])
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
