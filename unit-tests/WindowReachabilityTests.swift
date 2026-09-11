import XCTest

/// Scenarios from the Claude Desktop report (com.anthropic.claudefordesktop 1.32352.1, Electron 42.9.2):
/// after an OAuth sign-in, two 800x600 helper windows stay registered in the window server, keep their
/// AXStandardWindow subrole, but leave the accessibility window list of the application.
final class WindowReachabilityTests: XCTestCase {
    private func isUnreachable(_ facts: WindowReachabilityFacts, onScreen: Bool = false) -> Bool {
        return WindowReachabilityPolicy.isUnreachable(facts) { onScreen }
    }

    private func rejectsNewWindow(_ facts: WindowReachabilityFacts, onScreen: Bool = false) -> Bool {
        return WindowReachabilityPolicy.rejectsNewWindow(facts) { onScreen }
    }

    // 1. Claude before the sign-in: one 600x600 window, no CoreGraphics title, listed by the application
    func testListedSignInWindowStays() {
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .listed, isOnAnySpace: true), onScreen: true))
    }

    // 2. Claude during the sign-in: same window id, same missing title, only the content changed
    func testListedWindowStaysWhileItsContentChanges() {
        let facts = WindowReachabilityFacts(membership: .listed, isOnAnySpace: true)
        XCTAssertFalse(isUnreachable(facts, onScreen: true))
        XCTAssertFalse(rejectsNewWindow(facts, onScreen: true))
    }

    // 3. Claude after the sign-in: the main window stays, the two hidden OAuth windows go
    // the helper windows carry an empty accessibility title and no window-server title
    func testHiddenOauthHelperWindowsAreUnreachable() {
        let mainWindow = WindowReachabilityFacts(membership: .listed, isOnAnySpace: true)
        let helperWindow = WindowReachabilityFacts(membership: .notListed, hasOwnTitle: false, isOnAnySpace: false)
        XCTAssertFalse(isUnreachable(mainWindow, onScreen: true))
        XCTAssertTrue(isUnreachable(helperWindow))
        XCTAssertTrue(rejectsNewWindow(helperWindow))
    }

    // 4. a minimized window reports no Space and no kCGWindowIsOnscreen; the Dock still reaches it
    func testMinimizedWindowStays() {
        let facts = WindowReachabilityFacts(membership: .notListed, isMinimized: true, hasOwnTitle: false, isOnAnySpace: false)
        XCTAssertFalse(isUnreachable(facts))
        XCTAssertFalse(rejectsNewWindow(facts))
    }

    // 5. a window on another Space is absent from kAXWindowsAttribute, but it reports that Space
    func testWindowOnAnotherSpaceStays() {
        let facts = WindowReachabilityFacts(membership: .notListed, isOnAnySpace: true)
        XCTAssertFalse(isUnreachable(facts))
        XCTAssertFalse(rejectsNewWindow(facts))
    }

    // 6. a regular Electron window without a title of its own is kept as long as anything else reaches it
    func testTitlelessWindowStaysWhenAnythingElseReachesIt() {
        // the application still lists it
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .listed, hasOwnTitle: false, isOnAnySpace: false)))
        // a Space holds it
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .notListed, hasOwnTitle: false, isOnAnySpace: true)))
        // it is on screen
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .notListed, hasOwnTitle: false, isOnAnySpace: false), onScreen: true))
    }

    /// Observed on macOS 26: a Finder background tab reports no Space, no kCGWindowIsOnscreen, and it is
    /// absent from kAXWindowsAttribute. It keeps the title of its document, and AltTab+ does not always
    /// know that it is a tab: an application that draws its own tab bar exposes no AXTabGroup.
    func testBackgroundTabWithATitleStaysEvenWhenItIsNotKnownAsATab() {
        let knownTab = WindowReachabilityFacts(membership: .notListed, isTabbed: true, hasOwnTitle: true, isOnAnySpace: false)
        let unknownTab = WindowReachabilityFacts(membership: .notListed, isTabbed: false, hasOwnTitle: true, isOnAnySpace: false)
        XCTAssertFalse(isUnreachable(knownTab))
        XCTAssertFalse(isUnreachable(unknownTab))
        XCTAssertFalse(rejectsNewWindow(unknownTab))
    }

    // 7. an application without a usable accessibility window list keeps the previous behaviour
    func testApplicationWithoutAccessibilityListKeepsItsWindows() {
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .unknown, isOnAnySpace: true)))
        // we never refuse to add a window we cannot check against a list
        XCTAssertFalse(rejectsNewWindow(WindowReachabilityFacts(membership: .unknown, hasOwnTitle: false, isOnAnySpace: false)))
    }

    // 8. a dialog or a sheet the user works in sits on a Space and is on screen
    func testDialogStays() {
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .listed, isOnAnySpace: true), onScreen: true))
        XCTAssertFalse(isUnreachable(WindowReachabilityFacts(membership: .notListed, isOnAnySpace: true), onScreen: true))
    }

    func testWindowsOfAHiddenApplicationStay() {
        let facts = WindowReachabilityFacts(membership: .notListed, applicationIsHidden: true, hasOwnTitle: false, isOnAnySpace: false)
        XCTAssertFalse(isUnreachable(facts))
    }

    func testWindowOnScreenWithoutASpaceStays() {
        let facts = WindowReachabilityFacts(membership: .notListed, hasOwnTitle: false, isOnAnySpace: false)
        XCTAssertFalse(isUnreachable(facts, onScreen: true))
    }

    /// kCGWindowIsOnscreen costs one window-server call; the cheap facts must decide first
    func testOnScreenIsReadOnlyAsTheLastResort() {
        var reads = 0
        let onScreen = { () -> Bool in
            reads += 1
            return false
        }
        _ = WindowReachabilityPolicy.isUnreachable(WindowReachabilityFacts(membership: .listed), onScreen)
        _ = WindowReachabilityPolicy.isUnreachable(WindowReachabilityFacts(membership: .notListed, isMinimized: true), onScreen)
        _ = WindowReachabilityPolicy.isUnreachable(WindowReachabilityFacts(membership: .notListed, hasOwnTitle: true), onScreen)
        _ = WindowReachabilityPolicy.isUnreachable(WindowReachabilityFacts(membership: .notListed, hasOwnTitle: false, isOnAnySpace: true), onScreen)
        XCTAssertEqual(reads, 0)
        _ = WindowReachabilityPolicy.isUnreachable(WindowReachabilityFacts(membership: .notListed, hasOwnTitle: false, isOnAnySpace: false), onScreen)
        XCTAssertEqual(reads, 1)
    }
}
