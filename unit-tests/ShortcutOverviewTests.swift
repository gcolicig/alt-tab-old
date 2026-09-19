import XCTest

class ShortcutOverviewTests: XCTestCase {
    private func row(_ key: String, _ title: String, group: Int, _ status: ShortcutStatus, owner: String? = nil) -> ShortcutOverviewRow {
        ShortcutOverviewRow(key: key, title: title, groupOrder: group, groupTitle: "G\(group)", ownerSectionId: owner, status: status)
    }

    private var rows: [ShortcutOverviewRow] {
        [
            row("b", "Beta", group: 1, .ok),
            row("a", "Alpha", group: 1, .unassigned),
            row("c", "Gamma", group: 0, .duplicate(otherTitle: "Beta")),
            row("d", "Delta", group: 0, .replacesMacosShortcut, owner: "spaces"),
        ]
    }

    func testFilters() {
        XCTAssertEqual(ShortcutOverview.visible(rows, .all).count, 4)
        XCTAssertEqual(ShortcutOverview.visible(rows, .assigned).map(\.key), ["b", "c", "d"])
        XCTAssertEqual(ShortcutOverview.visible(rows, .conflicts).map(\.key), ["c"])
    }

    func testTakingOverAMacosShortcutIsNotAConflict() {
        XCTAssertFalse(ShortcutStatus.replacesMacosShortcut.isConflict)
        XCTAssertTrue(ShortcutStatus.reservedByMacos.isConflict)
        XCTAssertTrue(ShortcutStatus.usedByGameOverlay.isConflict)
    }

    func testGroupsFollowTheirOrderAndRowsTheirTitle() {
        let groups = ShortcutOverview.grouped(rows)
        XCTAssertEqual(groups.map(\.0), ["G0", "G1"])
        XCTAssertEqual(groups[0].1.map(\.title), ["Delta", "Gamma"])
        XCTAssertEqual(groups[1].1.map(\.title), ["Alpha", "Beta"])
    }

    func testSwitcherTriggersAreNotActionShortcuts() {
        XCTAssertFalse(ShortcutOverview.isActionShortcutKey("holdShortcut2"))
        XCTAssertFalse(ShortcutOverview.isActionShortcutKey("nextWindowShortcut"))
        XCTAssertTrue(ShortcutOverview.isActionShortcutKey("windowLayoutLeftThirdShortcut"))
    }
}
