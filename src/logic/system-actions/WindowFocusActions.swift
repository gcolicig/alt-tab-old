import Cocoa

/// Story 12: Isolate Window and the actions built from the same two blocks. No tap, no timer; AX work runs
/// on the accessibility queue and one unresponsive app never stops the others (WF-02, WF-07).
enum WindowFocusActions {
    static func perform(_ action: SystemAction) {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return NSSound.beep() }
        let pid = frontmost.processIdentifier
        switch action {
            case .hideOtherApps: hideApps(keeping: pid)
            case .hideAll: NSWorkspace.shared.hideOtherApplications()
            default: performWithFocusedWindow(action, pid)
        }
    }

    static func availability() -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        guard AccessibilityPermission.status == .granted else {
            return .unavailable(NSLocalizedString("Accessibility permission is missing.", comment: ""))
        }
        return .available
    }

    /// The focused window is read off the main thread; an app without one gets a beep instead of a guess.
    private static func performWithFocusedWindow(_ action: SystemAction, _ pid: pid_t) {
        guard pid != ProcessInfo.processInfo.processIdentifier else { return NSSound.beep() }
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            let windowId = focusedWindowId(pid)
            DispatchQueue.main.async {
                guard let windowId else { return NSSound.beep() }
                performResolved(action, pid, windowId)
            }
        }
    }

    private static func performResolved(_ action: SystemAction, _ pid: pid_t, _ windowId: CGWindowID) {
        switch action {
            case .isolateWindow:
                hideApps(keeping: pid)
                minimize(targetPid: pid, keeping: windowId)
            case .minimizeAppOthers: minimize(targetPid: pid, keeping: windowId)
            default: break
        }
    }

    private static func focusedWindowId(_ pid: pid_t) -> CGWindowID? {
        let application = AXUIElementCreateApplication(pid)
        guard let window = try? application.attributes([kAXFocusedWindowAttribute]).focusedWindow else { return nil }
        return try? window.cgWindowId()
    }

    private static func hideApps(keeping pid: pid_t) {
        let running = NSWorkspace.shared.runningApplications
        let pids = WindowFocusPlan.appsToHide(running.map(appInfo), keeping: pid)
        running.filter { pids.contains($0.processIdentifier) }.forEach { app in
            guard !app.hide() else { return }
            Logger.warning { "Focus action could not hide \(app.bundleIdentifier ?? "?")" }
        }
    }

    private static func appInfo(_ app: NSRunningApplication) -> FocusAppInfo {
        FocusAppInfo(pid: app.processIdentifier, isRegular: app.activationPolicy == .regular,
            isSelf: app.processIdentifier == ProcessInfo.processInfo.processIdentifier, isHidden: app.isHidden)
    }

    private static func minimize(targetPid: pid_t, keeping windowId: CGWindowID) {
        let windows = Windows.list.filter { $0.cgWindowId != nil && !$0.isWindowlessApp }
        let ids = WindowFocusPlan.windowsToMinimize(windows.map(windowInfo), targetPid: targetPid, keeping: windowId, visibleSpaces: Spaces.visibleSpaces.map { UInt64($0) })
        windows.filter { ids.contains($0.cgWindowId!) }.forEach(minimizeOnQueue)
    }

    private static func windowInfo(_ window: Window) -> FocusWindowInfo {
        FocusWindowInfo(id: window.cgWindowId!, pid: window.application.pid, isMinimized: window.isMinimized,
            isFullscreen: window.isFullscreen, isTabbed: window.isTabbed, spaceIds: window.spaceIds.map { UInt64($0) },
            isOnAllSpaces: window.isOnAllSpaces)
    }

    /// Unlike `Window.minDemin`, fullscreen windows never reach this point, so no Space is torn down.
    private static func minimizeOnQueue(_ window: Window) {
        guard let element = window.axUiElement else { return }
        let label = window.application.bundleIdentifier ?? "?"
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            do {
                try element.setAttribute(kAXMinimizedAttribute, true)
            } catch {
                Logger.warning { "Focus action could not minimize a window of \(label): \(error)" }
            }
        }
    }
}
