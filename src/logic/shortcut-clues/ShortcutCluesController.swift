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
    /// Identifies the hold a menu read belongs to. The read is slow enough to outlive its own session —
    /// that is why it runs on a queue at all — and without this a result arriving late was shown against
    /// whatever session happened to be current, so releasing in one app and holding in another displayed
    /// the first app's shortcuts under the first app's name.
    private static var generation: UInt64 = 0

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
        generation &+= 1
        let session = generation
        // a second press before the first has shown replaces the pending read rather than adding one
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { readAndShow(pid: pid, appName: name, session: session) }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    /// Called when the trigger is no longer held, and from every path that ends a session: safe mode, the
    /// emergency shortcut, losing permission. Leaves nothing behind.
    static func triggerReleased() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        // a read already in flight belongs to a session that is over; bumping retires it on arrival
        generation &+= 1
        guard visible else { return }
        visible = false
        ShortcutCluesPanel.hide()
    }

    static func clearCache() {
        cache = nil
    }

    private static func readAndShow(pid: pid_t, appName: String, session: UInt64) {
        guard session == generation else { return }
        if let cache, cache.pid == pid, ProcessInfo.processInfo.systemUptime - cache.readAt < cacheValidity {
            show(.shortcuts(cache.result, appName))
            return
        }
        AXCallScheduler.shared.submit {
            let result = MenuShortcutReader.read(pid: pid)
            DispatchQueue.main.async {
                // the scan is still worth keeping even when its session is gone: it is expensive, it is
                // keyed by pid, and the next hold in the same app is exactly what the cache is for
                if let result, !result.shortcuts.isEmpty {
                    cache = (pid, result, ProcessInfo.processInfo.systemUptime)
                }
                guard session == generation else { return }
                guard let result, !result.shortcuts.isEmpty else {
                    show(.empty(appName))
                    return
                }
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
