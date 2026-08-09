import Cocoa

class SleepWakeEvents {
    static func observe() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private static func handleWake(_ notification: Notification) {
        Logger.info { "" }
        reEnableAllTaps()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            reEnableAllTaps()
            Spaces.refresh()
            InstantSpaces.synchronize()
            Menubar.refreshSpaces()
            // the backlog requires a re-apply after wake; it runs through the same ownership check as any
            // write, so a value somebody else took over while asleep is left alone
            PointerOwnership.reapplyAfterSystemEvent()
        }
    }

    private static func reEnableAllTaps() {
        KeyboardEvents.resetHyperKeyState()
        TrackpadEvents.reEnableTapIfNeeded()
        ScrollwheelEvents.reEnableTapIfNeeded()
        KeyboardEvents.reEnableTapIfNeeded()
        CursorEvents.reEnableTapIfNeeded()
    }
}
