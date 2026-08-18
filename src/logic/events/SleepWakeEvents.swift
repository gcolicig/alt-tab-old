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
        // a Leader session must not survive a sleep; it rides the keyboard tap, so it only needs clearing
        LeaderController.reset()
        TrackpadEvents.reEnableTapIfNeeded()
        ScrollwheelEvents.reEnableTapIfNeeded()
        KeyboardEvents.reEnableTapIfNeeded()
        CursorEvents.reEnableTapIfNeeded()
        FlickRingEvents.reEnableTapIfNeeded()
    }
}
