import XCTest

class MenuLayoutTests: XCTestCase {
    private let entries = [
        MenuEntrySpec(id: "show", group: .switcher),
        MenuEntrySpec(id: "isolate", group: .windows),
        MenuEntrySpec(id: "pick", group: .tools),
        MenuEntrySpec(id: "settings", group: .app),
        MenuEntrySpec(id: "quit", group: .app),
    ]

    func testGroupsAreSeparatedAndHeadedInOrder() {
        let items = MenuLayout.build(entries, headersSupported: true) { _ in true }
        XCTAssertEqual(items, [
            .header(.switcher), .entry("show"), .separator,
            .header(.windows), .entry("isolate"), .separator,
            .header(.tools), .entry("pick"), .separator,
            .entry("settings"), .entry("quit"),
        ])
    }

    func testAnEmptyGroupLeavesNoHeaderOrSeparator() {
        let items = MenuLayout.build(entries, headersSupported: true) { $0.group != .tools }
        XCTAssertFalse(items.contains(.header(.tools)))
        XCTAssertFalse(zip(items, items.dropFirst()).contains { $0 == .separator && $1 == .separator })
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
        XCTAssertEqual(visible, [.switcher, .windows, .systemSettings, .app])
        XCTAssertFalse(MenuGroup.app.canBeHidden)
    }

    func testBrowserActionIdsRoundTrip() {
        XCTAssertEqual(DefaultBrowserActionId.bundleId(fromStableId: DefaultBrowserActionId.stableId("org.mozilla.firefox")), "org.mozilla.firefox")
        XCTAssertNil(DefaultBrowserActionId.bundleId(fromStableId: "browser.setDefault."))
        XCTAssertNil(DefaultBrowserActionId.bundleId(fromStableId: "windowFocus.isolate"))
    }

    func testSystemActionIdsAreUnique() {
        XCTAssertEqual(Set(SystemAction.allCases.map(\.rawValue)).count, SystemAction.allCases.count)
    }
}
