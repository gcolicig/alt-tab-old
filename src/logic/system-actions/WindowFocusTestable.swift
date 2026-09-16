import CoreGraphics
import Foundation

/// The two building blocks of story 12. Pure, so the selection rules (WF-03 to WF-06) are testable without
/// running apps.
struct FocusAppInfo: Equatable {
    let pid: pid_t
    let isRegular: Bool
    let isSelf: Bool
    let isHidden: Bool
}

struct FocusWindowInfo: Equatable {
    let id: CGWindowID
    let pid: pid_t
    let isMinimized: Bool
    let isFullscreen: Bool
    let isTabbed: Bool
    let spaceIds: [UInt64]
    let isOnAllSpaces: Bool
}

enum WindowScope {
    case targetApp
    case allApps
}

enum WindowFocusPlan {
    /// B1. The target app is never hidden, whatever the order of events (WF-06).
    static func appsToHide(_ apps: [FocusAppInfo], keeping targetPid: pid_t?) -> [pid_t] {
        apps.filter { $0.isRegular && !$0.isSelf && !$0.isHidden && $0.pid != targetPid }.map(\.pid)
    }

    /// B2. Only windows the user can see right now: not minimized, not in fullscreen (WF-04), not a tab
    /// behind another, and on a Space currently visible on some display (WF-05).
    static func windowsToMinimize(_ windows: [FocusWindowInfo], scope: WindowScope, targetPid: pid_t?, keeping targetWindowId: CGWindowID?, visibleSpaces: [UInt64]) -> [CGWindowID] {
        windows.filter { isCandidate($0, scope, targetPid, targetWindowId, visibleSpaces) }.map(\.id)
    }

    private static func isCandidate(_ window: FocusWindowInfo, _ scope: WindowScope, _ targetPid: pid_t?, _ targetWindowId: CGWindowID?, _ visibleSpaces: [UInt64]) -> Bool {
        guard window.id != targetWindowId, !window.isMinimized, !window.isFullscreen, !window.isTabbed else { return false }
        guard scope == .allApps || window.pid == targetPid else { return false }
        return window.isOnAllSpaces || window.spaceIds.contains { visibleSpaces.contains($0) }
    }
}
