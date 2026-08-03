import Cocoa

/// Per-toolkit accessibility quirks, kept in one place so the resolver and the drag path do not each grow
/// their own guesses. Both workarounds are opt-in per application and never applied blindly.
enum AxAppCompatibility {
    private static let lock = NSLock()
    private static var manualAccessibilityPids = Set<pid_t>()

    /// Electron exposes a stub tree until `AXManualAccessibility` is set on the application element: the
    /// element under the cursor comes back as a detached `AXGroup` whose parent chain never reaches the
    /// window. Setting it is the side-effect-free path Electron documents for assistive clients, unlike the
    /// Chromium attribute below.
    ///
    /// Returns true when this call was the one that enabled it, so a caller can retry its lookup once.
    @discardableResult
    static func enableManualAccessibilityIfNeeded(_ pid: pid_t) -> Bool {
        lock.lock()
        let alreadyEnabled = manualAccessibilityPids.contains(pid)
        if !alreadyEnabled { manualAccessibilityPids.insert(pid) }
        lock.unlock()
        guard !alreadyEnabled else { return false }
        let application = AXUIElementCreateApplication(pid)
        let result = AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard result == .success else {
            lock.lock()
            manualAccessibilityPids.remove(pid)
            lock.unlock()
            return false
        }
        Logger.debug { "enabled AXManualAccessibility for pid:\(pid)" }
        return true
    }

    /// Chromium turns `AXEnhancedUserInterface` on as soon as an assistive client attaches, and moving or
    /// resizing a window while it is on makes Chromium reflow and fight the write. It is suspended only for
    /// the duration of the operation and restored afterwards, never left off.
    ///
    /// Skipped entirely while a real assistive technology is running: clearing the flag under VoiceOver
    /// would degrade a tool the user actually depends on.
    static func withEnhancedUserInterfaceSuspended<T>(_ pid: pid_t, _ body: () -> T) -> T {
        guard !assistiveTechnologyIsActive else { return body() }
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, "AXEnhancedUserInterface" as CFString, &value) == .success,
              (value as? Bool) == true else { return body() }
        AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        defer { AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
        return body()
    }

    static var assistiveTechnologyIsActive: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.VoiceOver" }
    }

    static func forgetApplication(_ pid: pid_t) {
        lock.lock()
        manualAccessibilityPids.remove(pid)
        lock.unlock()
    }
}
