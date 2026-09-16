import Cocoa

/// Story 14B. Always asks first, also when triggered from a shortcut; apps with unsaved documents keep
/// their own prompt because only `terminate()` is ever sent.
enum AppQuit {
    private static let maxNamesInPrompt = 10

    static func quittableApps(keepingFrontmost: Bool) -> [NSRunningApplication] {
        let frontmost = keepingFrontmost ? NSWorkspace.shared.frontmostApplication?.processIdentifier : nil
        return NSWorkspace.shared.runningApplications.filter { isQuittable($0) && $0.processIdentifier != frontmost }
    }

    static func quitAll(keepingFrontmost: Bool) {
        let apps = quittableApps(keepingFrontmost: keepingFrontmost)
        guard !apps.isEmpty else { return NSSound.beep() }
        guard confirm(apps) else { return }
        apps.forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { reportSurvivors(apps) }
    }

    static func isQuittable(_ app: NSRunningApplication) -> Bool {
        guard app.activationPolicy == .regular, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        return app.bundleIdentifier != "com.apple.finder" || Preferences.finderShowsQuitMenuItem
    }

    private static func confirm(_ apps: [NSRunningApplication]) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(format: NSLocalizedString("Quit %d apps?", comment: ""), apps.count)
        alert.informativeText = QuitPrompt.names(apps.map { $0.localizedName ?? "?" }, limit: maxNamesInPrompt)
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }

    private static func reportSurvivors(_ apps: [NSRunningApplication]) {
        let survivors = apps.filter { !$0.isTerminated }.compactMap(\.localizedName)
        guard !survivors.isEmpty else { return }
        TransientNotice.show(String(format: NSLocalizedString("Still running: %@.", comment: ""), survivors.joined(separator: ", ")))
    }
}
