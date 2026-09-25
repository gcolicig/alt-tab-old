import XCTest

class WindowFocusTests: XCTestCase {
    override func tearDown() {
        SwitcherDiagnostics.reset()
        super.tearDown()
    }

    func testSwitcherDiagnosticsKeepsOnlyTheMostRecentEvents() {
        for index in 0...128 {
            SwitcherDiagnostics.record("test-\(index)")
        }
        let events = SwitcherDiagnostics.report().events
        XCTAssertEqual(events.count, 128)
        XCTAssertEqual(events.first?.kind, "test-1")
        XCTAssertEqual(events.last?.kind, "test-128")
    }

    private func app(_ pid: pid_t, regular: Bool = true, isSelf: Bool = false, hidden: Bool = false) -> FocusAppInfo {
        FocusAppInfo(pid: pid, isRegular: regular, isSelf: isSelf, isHidden: hidden)
    }

    private func window(_ id: CGWindowID, pid: pid_t, minimized: Bool = false, fullscreen: Bool = false, tabbed: Bool = false, spaces: [UInt64] = [1], allSpaces: Bool = false) -> FocusWindowInfo {
        FocusWindowInfo(id: id, pid: pid, isMinimized: minimized, isFullscreen: fullscreen, isTabbed: tabbed, spaceIds: spaces, isOnAllSpaces: allSpaces)
    }

    func testHidesOnlyOtherRegularVisibleApps() {
        let apps: [FocusAppInfo] = [app(1), app(2), app(3, regular: false), app(4, isSelf: true), app(5, hidden: true)]
        XCTAssertEqual(WindowFocusPlan.appsToHide(apps, keeping: 1), [2])
    }

    func testTargetAppIsNeverHidden() {
        XCTAssertEqual(WindowFocusPlan.appsToHide([app(7)], keeping: 7), [])
    }

    func testMinimizesOnlyOtherVisibleWindowsOfTheTargetApp() {
        let windows: [FocusWindowInfo] = [
            window(10, pid: 1), window(11, pid: 1), window(12, pid: 2),
            window(13, pid: 1, minimized: true), window(14, pid: 1, fullscreen: true),
            window(15, pid: 1, tabbed: true), window(16, pid: 1, spaces: [9]),
        ]
        let ids = WindowFocusPlan.windowsToMinimize(windows, targetPid: 1, keeping: 10, visibleSpaces: [1])
        XCTAssertEqual(ids, [11])
    }

    func testWindowsOnAllSpacesCountAsVisible() {
        let windows: [FocusWindowInfo] = [window(20, pid: 1, spaces: [], allSpaces: true)]
        XCTAssertEqual(WindowFocusPlan.windowsToMinimize(windows, targetPid: 1, keeping: nil, visibleSpaces: [1]), [20])
    }

    private func layouts(_ candidates: [(CGWindowID, CGFloat)]) -> [String] {
        FocusThreePlan.assign(candidates.map { FocusThreeCandidate(id: $0.0, midX: $0.1) }).map { "\($0.id):\($0.layout.rawValue)" }
    }

    func testThreeWindowsCentreTheFrontmostAndKeepTheBackWindowsOnTheirSides() {
        // window 2 sits right of window 3, so it keeps the right side
        XCTAssertEqual(layouts([(1, 500), (2, 900), (3, 100)]), ["3:leftFocus", "2:rightFocus", "1:centerFocus"])
        XCTAssertEqual(layouts([(1, 500), (2, 100), (3, 900)]), ["2:leftFocus", "3:rightFocus", "1:centerFocus"])
    }

    func testATieKeepsTheZOrder() {
        XCTAssertEqual(layouts([(1, 500), (2, 300), (3, 300)]), ["2:leftFocus", "3:rightFocus", "1:centerFocus"])
    }

    func testTheCentreWindowIsSetLast() {
        XCTAssertEqual(FocusThreePlan.assign([FocusThreeCandidate(id: 1, midX: 0), FocusThreeCandidate(id: 2, midX: 1)]).last?.layout, .centerFocus)
    }

    func testTwoWindowsKeepTheSideOfTheBackWindow() {
        XCTAssertEqual(layouts([(1, 500), (2, 100)]), ["2:leftFocus", "1:centerFocus"])
        XCTAssertEqual(layouts([(1, 500), (2, 900)]), ["2:rightFocus", "1:centerFocus"])
    }

    func testOnlyTheThreeForemostWindowsAreArranged() {
        XCTAssertEqual(layouts([(1, 500), (2, 100), (3, 900), (4, 50)]), ["2:leftFocus", "3:rightFocus", "1:centerFocus"])
    }

    func testOneWindowIsNotAnArrangement() {
        XCTAssertEqual(layouts([(1, 500)]), [])
        XCTAssertEqual(layouts([]), [])
    }
}
