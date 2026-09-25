import Cocoa

/// Keeps Teams' meeting mute indicator aligned with the microphone without ever background-unmuting it.
enum TeamsMuteSync {
    private static let bundleIdentifier = "com.microsoft.teams2"
    private static let meetingControls = "Meeting controls"
    private static let leave = "Leave"
    private static let mute = "Mute mic"
    private static let unmute = "Unmute mic"
    private static var timer: Timer?

    static func preferenceChanged() {
        timer?.invalidate()
        timer = nil
        guard Preferences.teamsMuteSync else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in reconcile(allowUnmute: false) }
        reconcile(allowUnmute: false)
    }

    /// Every caller is an explicit AltTab+ action. Only this path may make Teams unmute.
    static func microphoneToggled() {
        guard Preferences.teamsMuteSync else { return }
        reconcile(allowUnmute: true)
    }

    private static func reconcile(allowUnmute: Bool) {
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else { return }
            let pid = running.processIdentifier
            let enabledNow = AxAppCompatibility.enableManualAccessibilityIfNeeded(pid)
            if enabledNow {
                BackgroundWork.accessibilityCommandsQueue.addOperationAfter(deadline: .now() + .milliseconds(200)) { reconcile(allowUnmute: allowUnmute) }
                return
            }
            guard let control = muteControl(pid), let controlTitle = title(control) else { return }
            let systemMuted = AudioMute.isMuted(input: true)
            guard (systemMuted && controlTitle == mute) || (!systemMuted && allowUnmute && controlTitle == unmute) else { return }
            // AXPress is a toggle: require the same state twice before making an irreversible meeting change.
            BackgroundWork.accessibilityCommandsQueue.addOperationAfter(deadline: .now() + .milliseconds(200)) {
                guard let current = muteControl(pid), title(current) == controlTitle, AudioMute.isMuted(input: true) == systemMuted else { return }
                let result = AXUIElementPerformAction(current, kAXPressAction as CFString)
                if result != .success { Logger.warning { "Teams mute sync AXPress failed: \(result.rawValue)" } }
            }
        }
    }

    private static func muteControl(_ pid: pid_t) -> AXUIElement? {
        let root = AXUIElementCreateApplication(pid)
        guard contains(root, title: leave), let toolbar = find(root, role: kAXToolbarRole, title: meetingControls) else { return nil }
        return find(toolbar, role: kAXButtonRole, titles: [mute, unmute])
    }

    private static func contains(_ root: AXUIElement, title: String) -> Bool { find(root, role: kAXButtonRole, titles: [title]) != nil }

    private static func find(_ root: AXUIElement, role: String, title: String) -> AXUIElement? { find(root, role: role, titles: [title]) }

    private static func find(_ root: AXUIElement, role: String, titles: Set<String>) -> AXUIElement? {
        var queue = [root]
        var seen = 0
        while let element = queue.popLast(), seen < 300 {
            seen += 1
            if attribute(element, kAXRoleAttribute) == role, let value = title(element), titles.contains(value) { return element }
            queue.append(contentsOf: children(element))
        }
        return nil
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success ? value as? [AXUIElement] ?? [] : []
    }

    private static func title(_ element: AXUIElement) -> String? { attribute(element, kAXTitleAttribute) }

    private static func attribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value as? String : nil
    }
}
