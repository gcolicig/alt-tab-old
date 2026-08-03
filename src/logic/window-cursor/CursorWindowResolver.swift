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

    /// The drag session needs the element itself, not just its id, and it needs it exactly once at the
    /// start. Runs off the event callback: this makes blocking AX calls.
    static func resolveElement(at position: CGPoint) -> (element: AXUIElement, pid: pid_t)? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(position.x), Float(position.y), &hit) == .success, let element = hit else {
            Logger.debug { "drag resolve: no element at position" }
            return nil
        }
        guard let window = windowFor(element, at: position) else {
            Logger.debug { "drag resolve: no AXWindow ancestor, hit role:\(describeRole(element))" }
            return nil
        }
        guard let pid = try? window.pid() else {
            Logger.debug { "drag resolve: window has no pid" }
            return nil
        }
        guard isEligible(window) else {
            Logger.debug { "drag resolve: window rejected by filters, pid:\(pid) \(describeEligibility(window))" }
            return nil
        }
        return (window, pid)
    }

    private static func describeRole(_ element: AXUIElement) -> String {
        ((try? element.attributes([kAXRoleAttribute]))?.role) ?? "unknown"
    }

    private static func describeEligibility(_ window: AXUIElement) -> String {
        let attributes = try? window.attributes([kAXRoleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, kAXFullscreenAttribute])
        let positionSettable = (try? window.isAttributeSettable(kAXPositionAttribute)).map(String.init) ?? "error"
        let sizeSettable = (try? window.isAttributeSettable(kAXSizeAttribute)).map(String.init) ?? "error"
        return "role:\(attributes?.role ?? "nil") subrole:\(attributes?.subrole ?? "nil") minimized:\(String(describing: attributes?.isMinimized)) fullscreen:\(String(describing: attributes?.isFullscreen)) positionSettable:\(positionSettable) sizeSettable:\(sizeSettable)"
    }

    /// The exclusion filters from backlog section 1. A window that cannot be moved is left alone rather
    /// than mutated and hoped for.
    private static func isEligible(_ window: AXUIElement) -> Bool {
        guard let attributes = try? window.attributes([kAXRoleAttribute, kAXSubroleAttribute, kAXMinimizedAttribute, kAXFullscreenAttribute]),
              attributes.role == kAXWindowRole,
              attributes.isMinimized != true,
              attributes.isFullscreen != true,
              (try? window.isAttributeSettable(kAXPositionAttribute)) == true,
              (try? window.isAttributeSettable(kAXSizeAttribute)) == true else { return false }
        return true
    }

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

    /// Electron hands back a detached subtree until `AXManualAccessibility` is on, so a failed walk is
    /// retried once after enabling it. If the chain still does not reach a window, the application's own
    /// window list decides — but only when exactly one of its windows contains the point.
    private static func windowFor(_ element: AXUIElement, at position: CGPoint) -> AXUIElement? {
        if let window = ancestorWindow(element) { return window }
        guard let pid = try? element.pid() else { return nil }
        if AxAppCompatibility.enableManualAccessibilityIfNeeded(pid) {
            var retried: AXUIElement?
            if AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(position.x), Float(position.y), &retried) == .success,
               let hit = retried, let window = ancestorWindow(hit) {
                return window
            }
        }
        return windowOfApplication(pid, containing: position)
    }

    private static func windowOfApplication(_ pid: pid_t, containing position: CGPoint) -> AXUIElement? {
        guard let windows = try? AXUIElementCreateApplication(pid).attributes([kAXWindowsAttribute]).windows else { return nil }
        let matches = windows.filter { window in
            guard let attributes = try? window.attributes([kAXPositionAttribute, kAXSizeAttribute]),
                  let origin = attributes.position, let size = attributes.size else { return false }
            return CGRect(origin: origin, size: size).contains(position)
        }
        guard matches.count == 1 else {
            Logger.debug { "drag resolve: application window fallback found \(matches.count) candidates, refusing" }
            return nil
        }
        return matches[0]
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
