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

enum WindowFocusPlan {
    /// B1. The target app is never hidden, whatever the order of events (WF-06).
    static func appsToHide(_ apps: [FocusAppInfo], keeping targetPid: pid_t?) -> [pid_t] {
        apps.filter { $0.isRegular && !$0.isSelf && !$0.isHidden && $0.pid != targetPid }.map(\.pid)
    }

    /// B2. Only windows the user can see right now: not minimized, not in fullscreen (WF-04), not a tab
    /// behind another, and on a Space currently visible on some display (WF-05).
    static func windowsToMinimize(_ windows: [FocusWindowInfo], targetPid: pid_t, keeping targetWindowId: CGWindowID?, visibleSpaces: [UInt64]) -> [CGWindowID] {
        windows.filter { isCandidate($0, targetPid, targetWindowId, visibleSpaces) }.map(\.id)
    }

    private static func isCandidate(_ window: FocusWindowInfo, _ targetPid: pid_t, _ targetWindowId: CGWindowID?, _ visibleSpaces: [UInt64]) -> Bool {
        guard window.pid == targetPid, window.id != targetWindowId, !window.isMinimized, !window.isFullscreen, !window.isTabbed else { return false }
        return window.isOnAllSpaces || window.spaceIds.contains { visibleSpaces.contains($0) }
    }
}

/// One of the foremost windows, as the arrangement needs it: its position in the z-order is its index in
/// the list, so only the id and the horizontal centre are carried.
struct FocusThreeCandidate: Equatable {
    let id: CGWindowID
    let midX: CGFloat
}

/// "Focus on 3 Foremost Windows". The frontmost window is centred; the geometry leaves a thin edge on
/// each side of it, and the two windows behind fill those edges. A back window keeps the side it is on,
/// so the arrangement does not swap windows the user already placed.
enum FocusThreePlan {
    /// `candidates` are ordered frontmost first. Returns nothing for fewer than two windows: a single
    /// window is not an arrangement.
    static func assign(_ candidates: [FocusThreeCandidate]) -> [(id: CGWindowID, layout: WindowLayoutAction)] {
        guard candidates.count >= 2 else { return [] }
        let front = candidates[0]
        let back = Array(candidates[1..<min(3, candidates.count)])
        var result: [(id: CGWindowID, layout: WindowLayoutAction)] = []
        if back.count == 1 {
            result.append((back[0].id, back[0].midX < front.midX ? .leftFocus : .rightFocus))
        } else {
            // a tie keeps the z-order: the window nearer the front goes left
            let leftFirst = back[1].midX < back[0].midX ? [back[1], back[0]] : [back[0], back[1]]
            result.append((leftFirst[0].id, .leftFocus))
            result.append((leftFirst[1].id, .rightFocus))
        }
        // the centre window is set last, so it is the last one to move and stays on top
        result.append((front.id, .centerFocus))
        return result
    }
}
