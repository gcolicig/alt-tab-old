import Cocoa

class ScrollwheelEvents {
    private static var eventTap: CFMachPort!
    /// The switcher gesture wants continuous (trackpad) scrolling swallowed, so it cannot scroll the app
    /// underneath. Set for the duration of a gesture. Separate from the scroll-modifying settings, which
    /// keep the tap in the stream even when the switcher is closed.
    private static var switcherWantsTap = false
    /// Mirrors what was last handed to `CGEvent.tapEnable`, so a repeated toggle costs nothing. Written on
    /// main, read on the tap thread: same latitude as the flag above, whose worst case is one event treated
    /// by the previous setting at the moment it changes.
    ///
    /// A `scrollWheel` tap sees no gesture and no `mouseMoved` events, so it only makes the WindowServer
    /// wait for this process while the user is actually scrolling — the cost the trackpad tap split exists
    /// to avoid does not arise here. The measurement that confirms it is V-17.
    private static var tapEnabled = false

    static func observe() {
        observe_()
        // the user's settings apply from launch, not from the first visit to the settings tab
        scrollSettingsChanged()
    }

    /// Called by the switcher to demand (or release) continuous-scroll blocking.
    static func toggle(_ enabled: Bool) {
        switcherWantsTap = enabled
        updateEnabled()
    }

    /// Called when a Reverse/Speed setting or safe mode changes, so the tap starts or stops without the
    /// switcher. Safe mode wins over the settings without clearing them: the preference is the user's
    /// intent, safe mode is a temporary state. Leaving safe mode calls this again and the effect is back
    /// without a restart.
    static func scrollSettingsChanged() {
        updateEnabled()
    }

    static func disableForSafety() {
        guard eventTap != nil else { return }
        switcherWantsTap = false
        setEnabled(false)
    }

    static func reEnableTapIfNeeded() {
        guard let eventTap, tapEnabled, !CGEvent.tapIsEnabled(tap: eventTap) else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Logger.warning { "" }
    }

    /// The tap runs when the switcher wants blocking, or when a scroll-modifying setting is on (and input is
    /// not in safe mode). With nothing wanting it, no tap runs at all.
    private static func updateEnabled() {
        setEnabled(switcherWantsTap || scrollModifyActive())
    }

    private static func setEnabled(_ enabled: Bool) {
        guard enabled != tapEnabled else { return }
        tapEnabled = enabled
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: enabled)
        }
    }

    private static func scrollModifyActive() -> Bool {
        guard !Preferences.inputModulesSafeMode else { return false }
        return ScrollTransform.anyModifies(mouse: mouseSettings(), trackpad: trackpadSettings())
    }

    private static func mouseSettings() -> ScrollAxisSettings {
        ScrollAxisSettings(reverseVertical: Preferences.reverseScrollMouse, speed: Preferences.scrollSpeedMouse.factor)
    }

    private static func trackpadSettings() -> ScrollAxisSettings {
        ScrollAxisSettings(reverseVertical: Preferences.reverseScrollTrackpad, speed: Preferences.scrollSpeedTrackpad.factor)
    }

    private static func observe_() {
        // CGEvent.tapCreate returns null if ensureAccessibilityCheckboxIsChecked() didn't pass
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap, // we need raw data
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: NSEvent.EventTypeMask.scrollWheel.rawValue,
            callback: handleEvent,
            userInfo: nil)
        if let eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
            CFRunLoopAddSource(BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop, runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: false)
        } else {
            App.restart()
        }
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        guard type.rawValue == NSEvent.EventType.scrollWheel.rawValue else {
            if (type == .tapDisabledByUserInput || type == .tapDisabledByTimeout) && tapEnabled {
                CGEvent.tapEnable(tap: eventTap!, enable: true)
            }
            return Unmanaged.passUnretained(cgEvent)
        }
        // macOS marks trackpad and Magic Mouse scrolling as continuous and a notched wheel as discrete,
        // which is the only device distinction available without enumerating devices
        let isContinuous = cgEvent.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if switcherWantsTap {
            // block continuous (trackpad) scrolling in the switcher; let discrete (mouse) through
            // unchanged so it can move the selection
            return isContinuous ? nil : Unmanaged.passUnretained(cgEvent)
        }
        if scrollModifyActive() {
            applyTransform(cgEvent, isContinuous: isContinuous)
        }
        return Unmanaged.passUnretained(cgEvent) // focused app will receive the (possibly modified) event
    }

    /// Rewrites the event's scroll deltas in place. Axis 1 is vertical, axis 2 horizontal. The line, pixel,
    /// and fixed-point fields carry the same movement at different resolutions and each app reads the one
    /// it trusts, so they have to be rewritten together: flipping the line delta alone leaves pixel-precise
    /// views scrolling the old way, in the same app as everything else scrolls the new way.
    private static func applyTransform(_ cgEvent: CGEvent, isContinuous: Bool) {
        let settings = ScrollTransform.settings(isContinuous: isContinuous, mouse: mouseSettings(), trackpad: trackpadSettings())
        let vertical = ScrollTransform.verticalFactor(settings)
        let horizontal = ScrollTransform.horizontalFactor(settings)
        scaleIntField(cgEvent, .scrollWheelEventDeltaAxis1, vertical)
        scaleIntField(cgEvent, .scrollWheelEventDeltaAxis2, horizontal)
        scaleIntField(cgEvent, .scrollWheelEventPointDeltaAxis1, vertical)
        scaleIntField(cgEvent, .scrollWheelEventPointDeltaAxis2, horizontal)
        scaleDoubleField(cgEvent, .scrollWheelEventFixedPtDeltaAxis1, vertical)
        scaleDoubleField(cgEvent, .scrollWheelEventFixedPtDeltaAxis2, horizontal)
    }

    private static func scaleIntField(_ cgEvent: CGEvent, _ field: CGEventField, _ factor: Double) {
        let value = cgEvent.getIntegerValueField(field)
        guard value != 0 else { return }
        cgEvent.setIntegerValueField(field, value: Int64((Double(value) * factor).rounded()))
    }

    private static func scaleDoubleField(_ cgEvent: CGEvent, _ field: CGEventField, _ factor: Double) {
        let value = cgEvent.getDoubleValueField(field)
        guard value != 0 else { return }
        cgEvent.setDoubleValueField(field, value: value * factor)
    }
}
