import Foundation

/// What the application said about one of its windows the last time we read its accessibility window list.
/// `kAXWindowsAttribute` is the only list an application curates itself. The window server keeps windows
/// that the application ordered out but never destroyed, so the two sources disagree on purpose.
enum AxWindowListMembership: Equatable {
    /// the application returned the window in `kAXWindowsAttribute`
    case listed
    /// we read a usable list from the application, and the window was not in it
    case notListed
    /// we never read a usable list from this application (no accessibility support, or not asked yet)
    case unknown
}

/// The facts we can read about one window without asking its application. Every field has a fail-open
/// default: an unknown fact must never remove a window from the switcher.
struct WindowReachabilityFacts: Equatable {
    var membership = AxWindowListMembership.unknown
    /// `kAXMinimized`; the user reaches a minimized window through the Dock
    var isMinimized = false
    /// a background tab of a window tab group; the user reaches it through the tab bar
    var isTabbed = false
    /// the user reaches the windows of a hidden application by showing the application again
    var applicationIsHidden = false
    /// `CGSCopySpacesForWindows` returned at least one Space for this window
    var isOnAnySpace = true
}

/// Electron applications keep OAuth helper windows alive after they hide them. Such a window stays a
/// layer-0 window in the window server, keeps its `AXStandardWindow` subrole, and therefore passes every
/// check in `WindowDiscriminator`. The user cannot reach it: no Space holds it, it is not on screen, it is
/// not minimized, it is not a tab, and its application is not hidden.
///
/// This policy uses that combination instead of a title, a size, or `kCGWindowIsOnscreen` alone.
enum WindowReachabilityPolicy {
    /// True when the user has no way to bring this window up.
    ///
    /// `isOnScreen` reads `kCGWindowIsOnscreen` and costs one window-server call, so it is a closure: the
    /// cheap facts decide first, and a window that sits on a Space never pays for it.
    static func isUnreachable(_ facts: WindowReachabilityFacts, _ isOnScreen: () -> Bool) -> Bool {
        // the application curates this list; a listed window is a window the application still offers
        guard facts.membership != .listed else { return false }
        guard !facts.isMinimized && !facts.isTabbed && !facts.applicationIsHidden else { return false }
        // a window on another Space, or on another display, is reachable; it reports that Space
        guard !facts.isOnAnySpace else { return false }
        return !isOnScreen()
    }

    /// True when we must not add this window to the switcher at all.
    ///
    /// Stricter than `isUnreachable` on purpose: we drop a candidate only when the application itself did
    /// not list it. A window we learn about from a window-created notification is always added, even if the
    /// window server has not placed it on a Space yet; `isUnreachable` hides it later if it stays orphaned.
    static func rejectsNewWindow(_ facts: WindowReachabilityFacts, _ isOnScreen: () -> Bool) -> Bool {
        return facts.membership == .notListed && isUnreachable(facts, isOnScreen)
    }
}
