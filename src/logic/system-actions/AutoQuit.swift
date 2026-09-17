import Cocoa

/// Story 14C. Fed by the window list's own destroy events; a timer exists only for an app whose last window
/// just closed, and only while the setting is on.
enum AutoQuit {
    private static var pending = [pid_t: DispatchWorkItem]()

    static var rules: AutoQuitRules {
        AutoQuitRules(mode: AutoQuitMode(rawValue: Preferences.autoQuitMode) ?? .onlyListed,
            bundleIds: Set(AutoQuitPolicy.decodeList(Preferences.autoQuitBundleIds)))
    }

    static func toggle() {
        Preferences.set("autoQuitEnabled", Preferences.autoQuitEnabled ? "false" : "true")
    }

    static func enabledChanged() {
        guard !Preferences.autoQuitEnabled else { return }
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
    }

    static func windowsClosed(_ windows: [Window]) {
        guard Preferences.autoQuitEnabled else { return }
        let apps = Dictionary(windows.map { ($0.application.pid, $0.application) }, uniquingKeysWith: { first, _ in first })
        apps.values.filter(isCandidate).forEach(schedule)
    }

    private static func isCandidate(_ app: Application) -> Bool {
        let running = app.runningApplication
        return AutoQuitPolicy.applies(app.bundleIdentifier, rules: rules, isRegular: running.activationPolicy == .regular,
            isSelf: app.pid == ProcessInfo.processInfo.processIdentifier) && !hasWindows(app.pid)
    }

    /// Leaving an app is the only moment auto-quit hears about a window the app ordered out instead of
    /// destroying: no accessibility event reports that.
    static func appDeactivated(_ pid: pid_t) {
        guard Preferences.autoQuitEnabled, let app = Applications.list.first(where: { $0.pid == pid }), isCandidate(app) else { return }
        schedule(app)
    }

    private static func hasWindows(_ pid: pid_t) -> Bool {
        Windows.list.contains { window in
            guard window.application.pid == pid, !window.isWindowlessApp else { return false }
            guard let wid = window.cgWindowId else { return true }
            return AutoQuitPolicy.windowCountsAsOpen(isMinimized: window.isMinimized, appIsHidden: window.application.isHidden,
                isOnAnySpace: !wid.spaces().isEmpty, isOnScreen: { CGWindow.isOnScreen(wid) })
        }
    }

    private static func schedule(_ app: Application) {
        pending[app.pid]?.cancel()
        let running = app.runningApplication
        let pid = app.pid
        let item = DispatchWorkItem { quitIfStillIdle(running, pid) }
        pending[pid] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Preferences.autoQuitDelaySeconds), execute: item)
    }

    private static func quitIfStillIdle(_ running: NSRunningApplication, _ pid: pid_t) {
        pending.removeValue(forKey: pid)
        guard Preferences.autoQuitEnabled else { return }
        // the menu bar question goes to the other app over Accessibility, which can block; ask off the main thread
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            let menuBarItems = hasMenuBarItems(pid)
            DispatchQueue.main.async {
                guard Preferences.autoQuitEnabled,
                      AutoQuitPolicy.shouldQuitNow(hasWindows: hasWindows(pid), isFrontmost: running.isActive,
                          isTerminated: running.isTerminated, hasMenuBarItems: menuBarItems) else {
                    if menuBarItems { Logger.info { "Auto-quit skipped, app owns menu bar items: \(running.bundleIdentifier ?? "?")" } }
                    return
                }
                Logger.info { "Auto-quit \(running.bundleIdentifier ?? "?")" }
                running.terminate()
            }
        }
    }

    /// `AXExtrasMenuBar` is the app's own status items. A failed query counts as having items: when in doubt,
    /// the app keeps running.
    private static func hasMenuBarItems(_ pid: pid_t) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), "AXExtrasMenuBar" as CFString, &value)
        switch result {
            case .success: return value != nil
            case .noValue, .attributeUnsupported: return false
            default: return true
        }
    }

    static func addApps(_ bundleIds: [String]) {
        let merged = Array(Set(AutoQuitPolicy.decodeList(Preferences.autoQuitBundleIds) + bundleIds)).sorted()
        Preferences.set("autoQuitBundleIds", AutoQuitPolicy.encodeList(merged))
    }

    static func removeApp(_ bundleId: String) {
        let remaining = AutoQuitPolicy.decodeList(Preferences.autoQuitBundleIds).filter { $0 != bundleId }
        Preferences.set("autoQuitBundleIds", AutoQuitPolicy.encodeList(remaining))
    }
}
