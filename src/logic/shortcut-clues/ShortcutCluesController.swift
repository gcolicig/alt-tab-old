import Cocoa

/// Shows the active app's menu shortcuts while a trigger is held. It is a lookup, not an execution path:
/// nothing is absorbed, so pressing one of the shown shortcuts runs it in the target app.
enum ShortcutCluesController {
    static let shortcutPreferenceKey = "shortcutCluesShortcut"
    /// The overlay is a lookup aid, so it should not flash up on a shortcut the user meant to press
    /// quickly. The spec's guide value.
    private static let showDelay = 0.3
    /// A menu can change while the app runs, so a cached scan is short-lived rather than kept for the
    /// session.
    private static let cacheValidity = 20.0

    fileprivate static var visible = false
    fileprivate static var pendingWorkItem: DispatchWorkItem?
    private static var cache: (pid: pid_t, result: MenuShortcutReader.Result, readAt: TimeInterval)?

    static var isEnabled: Bool {
        Preferences.shortcut(shortcutPreferenceKey) != nil && !Preferences.inputModulesSafeMode
    }

    /// Called when the trigger goes down. The read runs on the AX queue: walking a menu bar is many
    /// synchronous AX calls and must never happen in an event callback.
    static func triggerPressed() {
        guard isEnabled, !visible else { return }
        guard AXIsProcessTrusted() else {
            show(.permissionMissing)
            return
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let pid = application.processIdentifier
        let name = application.localizedName ?? ""
        let work = DispatchWorkItem { readAndShow(pid: pid, appName: name) }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    /// Called when the trigger is no longer held, and from every path that ends a session: safe mode, the
    /// emergency shortcut, losing permission. Leaves nothing behind.
    static func triggerReleased() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        guard visible else { return }
        visible = false
        ShortcutCluesPanel.hide()
    }

    static func clearCache() {
        cache = nil
    }

    private static func readAndShow(pid: pid_t, appName: String) {
        if let cache, cache.pid == pid, ProcessInfo.processInfo.systemUptime - cache.readAt < cacheValidity {
            show(.shortcuts(cache.result, appName))
            return
        }
        AXCallScheduler.shared.submit {
            let result = MenuShortcutReader.read(pid: pid)
            DispatchQueue.main.async {
                guard pendingWorkItem != nil || visible else { return }
                guard let result, !result.shortcuts.isEmpty else {
                    show(.empty(appName))
                    return
                }
                cache = (pid, result, ProcessInfo.processInfo.systemUptime)
                show(.shortcuts(result, appName))
            }
        }
    }

    private static func show(_ content: ShortcutCluesPanel.Content) {
        visible = true
        ShortcutCluesPanel.show(content)
    }
}

extension ShortcutCluesController {
    /// The trigger is a held shortcut, so the release shows up as a modifier change. Anything that no
    /// longer satisfies the configured combination closes the overlay; nothing is absorbed either way.
    static func modifiersChanged(_ modifiers: NSEvent.ModifierFlags) {
        guard visible || pendingWorkItem != nil else { return }
        guard let shortcut = Preferences.shortcut(shortcutPreferenceKey) else {
            triggerReleased()
            return
        }
        let required = shortcut.modifierFlags.intersection(LeaderKey.relevantModifiers)
        if !modifiers.intersection(LeaderKey.relevantModifiers).contains(required) {
            triggerReleased()
        }
    }
}
