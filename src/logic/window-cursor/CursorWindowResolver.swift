import Cocoa

/// Identifies the window a cursor-driven operation acts on. Runs once at the start of a drag session, never
/// per mouse-moved event: re-resolving mid-drag is how a window swap under the cursor turns into moving the
/// wrong window.
///
/// The chain follows backlog section 1. Each stage is attempted only when the previous one failed, and the
/// ordering itself lives in `CursorWindowResolutionPolicy` so it can be tested without a window server.
enum CursorWindowResolver {
    /// Ancestor walks are bounded: a malformed hierarchy must not spin here, and a real window is a handful
    /// of levels above the element under the cursor.
    private static let maximumAncestorDepth = 12

    static func resolve(at position: CGPoint) -> CursorWindowResolution {
        var candidates = CursorWindowCandidates()
        candidates.elementWindow = windowUnderCursor(position)
        if candidates.elementWindow == nil {
            candidates.focusedWindow = focusedWindow()
        }
        if candidates.elementWindow == nil, candidates.focusedWindow == nil {
            candidates.boundsMatches = windowsContaining(position)
        }
        return CursorWindowResolutionPolicy.resolve(candidates)
    }

    private static func windowUnderCursor(_ position: CGPoint) -> CGWindowID? {
        var element: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(systemWide, Float(position.x), Float(position.y), &element) == .success,
              let hit = element,
              let window = ancestorWindow(hit) else { return nil }
        return try? window.cgWindowId()
    }

    private static func ancestorWindow(_ element: AXUIElement) -> AXUIElement? {
        var current = element
        for _ in 0..<maximumAncestorDepth {
            guard let attributes = try? current.attributes([kAXRoleAttribute, kAXParentAttribute]) else { return nil }
            if attributes.role == kAXWindowRole { return current }
            guard let parent = attributes.parent else { return nil }
            current = parent
        }
        return nil
    }

    private static func focusedWindow() -> CGWindowID? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let application = AXUIElementCreateApplication(pid)
        guard let window = try? application.attributes([kAXFocusedWindowAttribute]).focusedWindow else { return nil }
        return try? window.cgWindowId()
    }

    /// Last resort, and the only stage that can come back ambiguous: overlapping windows all contain the
    /// point, and picking one of them would be a guess.
    private static func windowsContaining(_ position: CGPoint) -> [CGWindowID] {
        let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return infos.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.contains(position) else { return nil }
            return number
        }
    }
}
