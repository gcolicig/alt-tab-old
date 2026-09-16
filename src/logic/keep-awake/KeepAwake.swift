import Cocoa
import IOKit.ps
import IOKit.pwr_mgt

/// Story 10, MVP. Only public power assertions; exactly one per kind, never persisted, so a crash or a
/// restart leaves the Mac in its normal state (fail-safe).
enum KeepAwake {
    private static var systemAssertion: IOPMAssertionID?
    private static var displayAssertion: IOPMAssertionID?
    private static var timer: Timer?
    private static var wakeObserver: NSObjectProtocol?
    private(set) static var session: KeepAwakeSession?
    private(set) static var state = KeepAwakeState.inactive

    static var isActive: Bool { session != nil }

    static func toggle() {
        isActive ? stop(reason: nil) : start(KeepAwakeDuration(rawValue: Preferences.keepAwakeLastDuration) ?? .hour1)
    }

    static func start(_ duration: KeepAwakeDuration) {
        Preferences.set("keepAwakeLastDuration", String(duration.rawValue), false)
        begin(.starting(duration, keepDisplayAwake: Preferences.keepAwakeDisplay, now: Date()))
    }

    static func start(until date: Date) {
        begin(.until(date, keepDisplayAwake: Preferences.keepAwakeDisplay))
    }

    static func extend(by seconds: TimeInterval) {
        guard let session else { return }
        self.session = session.extended(by: seconds, now: Date())
    }

    static func stop(reason: String?) {
        guard isActive else { return }
        session = nil
        releaseAssertions()
        timer?.invalidate()
        timer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        state = .inactive
        if let reason { TransientNotice.show(reason) }
    }

    static func displayPreferenceChanged() {
        guard let session else { return }
        begin(KeepAwakeSession(endsAt: session.endsAt, keepDisplayAwake: Preferences.keepAwakeDisplay))
    }

    static func releaseOnQuit() {
        releaseAssertions()
    }

    static func menuTitle() -> String {
        let base = NSLocalizedString("Keep Awake", comment: "")
        guard let remaining = session?.remaining(at: Date()) else { return base }
        return base + "  " + KeepAwakeClock.format(remaining)
    }

    private static func begin(_ newSession: KeepAwakeSession) {
        guard !batteryShouldEnd() else {
            state = .batteryProtected
            return TransientNotice.show(NSLocalizedString("Keep Awake did not start: the battery is low.", comment: ""))
        }
        session = newSession
        guard applyAssertions(newSession) else {
            stop(reason: nil)
            state = .error
            return TransientNotice.show(NSLocalizedString("Keep Awake could not start.", comment: ""))
        }
        state = newSession.keepDisplayAwake ? .active : .displayAllowedToSleep
        startTimer()
    }

    private static func applyAssertions(_ session: KeepAwakeSession) -> Bool {
        systemAssertion = systemAssertion ?? createAssertion(kIOPMAssertPreventUserIdleSystemSleep)
        if session.keepDisplayAwake {
            displayAssertion = displayAssertion ?? createAssertion(kIOPMAssertPreventUserIdleDisplaySleep)
        } else if let id = displayAssertion {
            IOPMAssertionRelease(id)
            displayAssertion = nil
        }
        return systemAssertion != nil && (!session.keepDisplayAwake || displayAssertion != nil)
    }

    private static func createAssertion(_ type: String) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "AltTab+ Keep Awake" as CFString, &id)
        guard result == kIOReturnSuccess else {
            Logger.error { "Keep Awake assertion \(type) failed: \(result)" }
            return nil
        }
        return id
    }

    private static func releaseAssertions() {
        [systemAssertion, displayAssertion].compactMap { $0 }.forEach { IOPMAssertionRelease($0) }
        systemAssertion = nil
        displayAssertion = nil
    }

    /// A coarse wall-clock check; the tolerance lets the system coalesce wakeups.
    private static func startTimer() {
        guard timer == nil else { return }
        let newTimer = Timer(timeInterval: 30, repeats: true) { _ in tick() }
        newTimer.tolerance = 10
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in tick() }
    }

    private static func tick() {
        guard let session else { return }
        if session.isExpired(at: Date()) {
            return stop(reason: NSLocalizedString("Keep Awake ended.", comment: ""))
        }
        if batteryShouldEnd() {
            stop(reason: NSLocalizedString("Keep Awake ended because the battery is low.", comment: ""))
            state = .batteryProtected
        }
    }

    private static func batteryShouldEnd() -> Bool {
        let (level, onBattery) = batteryStatus()
        return KeepAwakeClock.batteryShouldEnd(level: level, onBattery: onBattery, threshold: Preferences.keepAwakeBatteryThreshold)
    }

    private static func batteryStatus() -> (Int?, Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return (nil, false) }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let level = description[kIOPSCurrentCapacityKey] as? Int
            return (level, description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue)
        }
        return (nil, false)
    }

    /// "Until…" asks for a time of day; a time already past today means tomorrow.
    static func askUntil() {
        let picker = NSDatePicker(frame: CGRect(x: 0, y: 0, width: 120, height: 24))
        picker.datePickerElements = .hourMinute
        picker.datePickerStyle = .textFieldAndStepper
        picker.dateValue = Date().addingTimeInterval(3600)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Keep the Mac awake until", comment: "")
        alert.accessoryView = picker
        alert.addButton(withTitle: NSLocalizedString("Start", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: picker.dateValue)
        guard let end = KeepAwakeClock.nextOccurrence(hour: parts.hour ?? 0, minute: parts.minute ?? 0, after: Date()) else { return }
        start(until: end)
    }
}
