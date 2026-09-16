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

    private static func hasWindows(_ pid: pid_t) -> Bool {
        Windows.list.contains { $0.application.pid == pid && !$0.isWindowlessApp }
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
        guard Preferences.autoQuitEnabled,
              AutoQuitPolicy.shouldQuitNow(hasWindows: hasWindows(pid), isFrontmost: running.isActive, isTerminated: running.isTerminated) else { return }
        Logger.info { "Auto-quit \(running.bundleIdentifier ?? "?")" }
        running.terminate()
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
