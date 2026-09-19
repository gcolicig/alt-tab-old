import XCTest

class SettingsSidebarTests: XCTestCase {
    func testGroupsGetHeadingsAndKeepTheirOrder() {
        let rows = SettingsSidebarLayout.rows(["general", "hyperkey", "pointer-scroll", "leader"])
        let expected: [SettingsSidebarRow] = [
            .header(.app), .section("general"),
            .header(.input), .section("hyperkey"), .section("pointer-scroll"), .section("leader"),
        ]
        XCTAssertEqual(rows, expected)
    }

    func testGroupsWithoutVisibleSectionsDisappear() {
        let rows = SettingsSidebarLayout.rows(["exceptions"])
        let expected: [SettingsSidebarRow] = [.header(.switcher), .section("exceptions")]
        XCTAssertEqual(rows, expected)
        XCTAssertEqual(SettingsSidebarLayout.rows([]), [])
    }

    func testUnknownSectionsFallBackToActions() {
        XCTAssertEqual(SettingsSidebarLayout.group(of: "something-new"), .actions)
        XCTAssertEqual(SettingsSidebarLayout.order(["something-new", "apps-urls", "general"]), ["general", "apps-urls", "something-new"])
    }

    func testEveryKnownSectionHasExactlyOneGroup() {
        let ids = SettingsSidebarLayout.sectionsByGroup.flatMap(\.1)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryRegisteredSectionIdMapsToAGroupWithoutFallingBack() {
        let known = Set(SettingsSidebarLayout.sectionsByGroup.flatMap(\.1))
        for id in SettingsSidebarLayout.allSectionIds {
            XCTAssertTrue(known.contains(id), "\(id) is not listed in sectionsByGroup and would silently fall back to .actions")
        }
    }

    func testNoSectionIdIsListedTwice() {
        let ids = SettingsSidebarLayout.allSectionIds
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testShortcutsAndPointerScrollAreGroupedUnderInput() {
        XCTAssertEqual(SettingsSidebarLayout.group(of: "shortcuts"), .input)
        XCTAssertEqual(SettingsSidebarLayout.group(of: "pointer-scroll"), .input)
    }

    func testSelectionKeepsTheChosenPageWhileItIsVisible() {
        XCTAssertEqual(SettingsSidebarLayout.selection(visible: ["general", "leader"], preferred: "leader"), "leader")
        XCTAssertEqual(SettingsSidebarLayout.selection(visible: ["general", "leader"], preferred: "spaces"), "general")
        XCTAssertNil(SettingsSidebarLayout.selection(visible: [], preferred: "spaces"))
    }

    func testOnlyTheSelectedPageIsShownWithoutAQuery() {
        let all = ["general", "leader", "spaces"]
        XCTAssertEqual(SettingsSidebarLayout.displayed(all: all, matching: all, selected: "leader", searching: false), ["leader"])
        XCTAssertEqual(SettingsSidebarLayout.displayed(all: all, matching: ["spaces", "general"], selected: "leader", searching: true), ["general", "spaces"])
    }

    func testSearchPathJoinsGroupPageAndSections() {
        XCTAssertEqual(SettingsSidebarLayout.searchPath(groupTitle: "Switcher", pageTitle: "Cmd-Tab", sectionTitles: ["Animations"]),
                       "Switcher › Cmd-Tab › Animations")
    }

    func testSearchPathWithoutMatchingSectionsStaysAtGroupAndPage() {
        XCTAssertEqual(SettingsSidebarLayout.searchPath(groupTitle: "Input", pageTitle: "Leader", sectionTitles: []), "Input › Leader")
    }

    func testSearchPathDeduplicatesSectionTitlesInOrder() {
        XCTAssertEqual(SettingsSidebarLayout.searchPath(groupTitle: "Input", pageTitle: "Leader", sectionTitles: ["Timing", "Timing"]),
                       "Input › Leader › Timing")
    }

    func testSearchPathCapsSectionTitlesAtTwoWithEllipsis() {
        XCTAssertEqual(SettingsSidebarLayout.searchPath(groupTitle: "Switcher", pageTitle: "Cmd-Tab", sectionTitles: ["Animations", "Style", "Position"]),
                       "Switcher › Cmd-Tab › Animations › Style › …")
    }

    func testHighlightingStaysOffBelowTwoCharacters() {
        XCTAssertFalse(SettingsSidebarLayout.shouldHighlightMatches(""))
        XCTAssertFalse(SettingsSidebarLayout.shouldHighlightMatches("t"))
        XCTAssertFalse(SettingsSidebarLayout.shouldHighlightMatches(" t "))
    }

    func testHighlightingStartsAtTwoCharacters() {
        XCTAssertTrue(SettingsSidebarLayout.shouldHighlightMatches("th"))
        XCTAssertTrue(SettingsSidebarLayout.shouldHighlightMatches("theme"))
        XCTAssertTrue(SettingsSidebarLayout.shouldHighlightMatches("  th  "))
    }
}
