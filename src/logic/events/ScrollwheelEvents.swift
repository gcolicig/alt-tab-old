import Cocoa

class ScrollwheelEvents {
    static var shouldBeEnabled: Bool!
    private static var eventTap: CFMachPort!
    /// Set by the switcher: while it is up, continuous (trackpad) scrolling is blocked so it cannot scroll
    /// the app underneath. Separate from the scroll-modifying settings, which run the tap even when the
    /// switcher is closed.
    private static var switcherWantsTap = false

    static func observe() {
        observe_()
        toggle(false)
    }

    /// Called by the switcher to demand (or release) continuous-scroll blocking.
    static func toggle(_ enabled: Bool) {
        switcherWantsTap = enabled
        updateEnabled()
    }

    /// Called when a Reverse/Speed setting changes, so the tap starts or stops without the switcher.
    static func scrollSettingsChanged() {
        updateEnabled()
    }

    static func disableForSafety() {
        guard eventTap != nil else { return }
        switcherWantsTap = false
        setEnabled(false)
    }

    static func reEnableTapIfNeeded() {
        guard let eventTap, shouldBeEnabled, !CGEvent.tapIsEnabled(tap: eventTap) else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Logger.warning { "" }
    }

    /// The tap runs when the switcher wants blocking, or when a scroll-modifying setting is on (and input is
    /// not in safe mode). With nothing wanting it, no tap runs at all.
    private static func updateEnabled() {
        setEnabled(switcherWantsTap || scrollModifyActive())
    }

    private static func setEnabled(_ enabled: Bool) {
        guard enabled != shouldBeEnabled else { return }
        shouldBeEnabled = enabled
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
        } else {
            App.restart()
        }
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        if type.rawValue == NSEvent.EventType.scrollWheel.rawValue {
            let isContinuous = cgEvent.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            if switcherWantsTap {
                // block continuous (trackpad) scrolling in the switcher; let discrete (mouse) through
                // unchanged so it can move the selection
                return isContinuous ? nil : Unmanaged.passUnretained(cgEvent)
            }
            if scrollModifyActive() {
                applyTransform(cgEvent, isContinuous: isContinuous)
            }
        } else if (type == .tapDisabledByUserInput || type == .tapDisabledByTimeout) && shouldBeEnabled {
            CGEvent.tapEnable(tap: eventTap!, enable: true)
        }
        return Unmanaged.passUnretained(cgEvent) // focused app will receive the (possibly modified) event
    }

    /// Rewrites the event's scroll deltas in place. Every axis-1 (vertical) and axis-2 (horizontal) field is
    /// scaled so the line, pixel, and fixed-point views of the same scroll stay consistent.
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
