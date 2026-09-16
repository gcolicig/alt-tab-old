import XCTest

class WindowFocusTests: XCTestCase {
    private func app(_ pid: pid_t, regular: Bool = true, isSelf: Bool = false, hidden: Bool = false) -> FocusAppInfo {
        FocusAppInfo(pid: pid, isRegular: regular, isSelf: isSelf, isHidden: hidden)
    }

    private func window(_ id: CGWindowID, pid: pid_t, minimized: Bool = false, fullscreen: Bool = false, tabbed: Bool = false, spaces: [UInt64] = [1], allSpaces: Bool = false) -> FocusWindowInfo {
        FocusWindowInfo(id: id, pid: pid, isMinimized: minimized, isFullscreen: fullscreen, isTabbed: tabbed, spaceIds: spaces, isOnAllSpaces: allSpaces)
    }

    func testHidesOnlyOtherRegularVisibleApps() {
        let apps = [app(1), app(2), app(3, regular: false), app(4, isSelf: true), app(5, hidden: true)]
        XCTAssertEqual(WindowFocusPlan.appsToHide(apps, keeping: 1), [2])
    }

    func testTargetAppIsNeverHidden() {
        XCTAssertEqual(WindowFocusPlan.appsToHide([app(7)], keeping: 7), [])
    }

    func testMinimizesOnlyOtherVisibleWindowsOfTheTargetApp() {
        let windows = [
            window(10, pid: 1), window(11, pid: 1), window(12, pid: 2),
            window(13, pid: 1, minimized: true), window(14, pid: 1, fullscreen: true),
            window(15, pid: 1, tabbed: true), window(16, pid: 1, spaces: [9]),
        ]
        let ids = WindowFocusPlan.windowsToMinimize(windows, scope: .targetApp, targetPid: 1, keeping: 10, visibleSpaces: [1])
        XCTAssertEqual(ids, [11])
    }

    func testWindowsOnAllSpacesCountAsVisible() {
        let windows = [window(20, pid: 1, spaces: [], allSpaces: true)]
        XCTAssertEqual(WindowFocusPlan.windowsToMinimize(windows, scope: .targetApp, targetPid: 1, keeping: nil, visibleSpaces: [1]), [20])
    }

    func testAllAppsScopeKeepsOnlyTheTargetWindow() {
        let windows = [window(30, pid: 1), window(31, pid: 2), window(32, pid: 3, fullscreen: true)]
        XCTAssertEqual(WindowFocusPlan.windowsToMinimize(windows, scope: .allApps, targetPid: 1, keeping: 30, visibleSpaces: [1]), [31])
    }
}
