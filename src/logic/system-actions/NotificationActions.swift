import Cocoa

/// Story 14H. Remote-controls Notification Center through accessibility. There is no public interface for
/// this, so the structure it relies on is gated by macOS major version (SA-06, Q-09): an unknown version
/// disables the actions instead of guessing. Verified structure: none yet, see V-21.
enum NotificationActions {
    static let supportedMajorVersions: Set<Int> = [26]
    private static let closeActionNames = ["Close", "Clear", "Schliessen", "Löschen"]
    private static let clearAllActionNames = ["Clear All", "Alle löschen"]
    private static let maxDepth = 8

    static func availability() -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        guard supportedMajorVersions.contains(ProcessInfo.processInfo.operatingSystemVersion.majorVersion) else {
            return .unavailable(NSLocalizedString("Not supported on this macOS version.", comment: ""))
        }
        guard AccessibilityPermission.status == .granted else {
            return .unavailable(NSLocalizedString("Accessibility permission is missing.", comment: ""))
        }
        return .available
    }

    static func clear(all: Bool) {
        guard availability().isAvailable, let pid = notificationCenterPid() else { return NSSound.beep() }
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            let count = pressActions(AXUIElementCreateApplication(pid), names: all ? clearAllActionNames + closeActionNames : closeActionNames)
            DispatchQueue.main.async { announce(count) }
        }
    }

    private static func notificationCenterPid() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first?.processIdentifier
    }

    /// Walks the tree once and performs every matching named action, deepest first so a group's close
    /// button does not remove the children before they are visited.
    private static func pressActions(_ root: AXUIElement, names: [String]) -> Int {
        var pressed = 0
        visit(root, depth: 0) { element in
            guard let action = matchingAction(element, names) else { return }
            if AXUIElementPerformAction(element, action as CFString) == .success { pressed += 1 }
        }
        return pressed
    }

    private static func visit(_ element: AXUIElement, depth: Int, _ body: (AXUIElement) -> Void) {
        guard depth < maxDepth else { return }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success, let children = value as? [AXUIElement] {
            children.forEach { visit($0, depth: depth + 1, body) }
        }
        body(element)
    }

    /// Notification Center exposes its buttons as custom actions named like `Name:Close`.
    private static func matchingAction(_ element: AXUIElement, _ names: [String]) -> String? {
        var actions: CFArray?
        guard AXUIElementCopyActionNames(element, &actions) == .success, let list = actions as? [String] else { return nil }
        return list.first { action in names.contains { action == $0 || action.hasSuffix(":" + $0) || action.hasPrefix("Name:" + $0) } }
    }

    private static func announce(_ count: Int) {
        guard count > 0 else { return TransientNotice.show(NSLocalizedString("No notifications to clear.", comment: "")) }
        TransientNotice.show(String(format: NSLocalizedString("Cleared %d notification(s).", comment: ""), count))
    }
}
