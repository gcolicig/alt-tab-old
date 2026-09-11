import Cocoa

class ScrollwheelEvents {
    private static var eventTap: CFMachPort!
    /// The switcher gesture wants continuous scrolling swallowed. Set for the duration of a gesture.
    private static var absorbContinuous = false
    /// The user's scroll direction setting wants discrete scrolling mirrored. Unlike absorbing, this is not
    /// tied to a session: while it is on, the tap stays in the stream. A `scrollWheel` tap sees no gesture
    /// and no `mouseMoved` events, so it only makes the WindowServer wait for this process while the user
    /// is actually scrolling — the cost the trackpad tap split exists to avoid does not arise here. The
    /// measurement that confirms it is V-17.
    private static var rewriteDiscrete = false
    /// Mirrors what was last handed to `CGEvent.tapEnable`, so a repeated toggle costs nothing. Written on
    /// main, read on the tap thread: same latitude as the flags above, whose worst case is one event
    /// treated by the previous setting at the moment it changes.
    private static var tapEnabled = false

    static func observe() {
        observe_()
        directionPreferenceChanged()
    }

    static func toggle(_ enabled: Bool) {
        guard enabled != absorbContinuous else { return }
        absorbContinuous = enabled
        applyTapState()
    }

    /// Safe mode wins over the setting, and it does so without clearing it: the preference is the user's
    /// intent, safe mode is a temporary state. Leaving safe mode calls this again and the direction is back
    /// without a restart.
    static func directionPreferenceChanged() {
        let wanted = Preferences.scrollReverseMouse && !Preferences.inputModulesSafeMode
        guard wanted != rewriteDiscrete else { return }
        rewriteDiscrete = wanted
        applyTapState()
    }

    static func disableForSafety() {
        guard eventTap != nil else { return }
        absorbContinuous = false
        rewriteDiscrete = false
        applyTapState()
    }

    static func reEnableTapIfNeeded() {
        guard let eventTap, tapEnabled, !CGEvent.tapIsEnabled(tap: eventTap) else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Logger.warning { "" }
    }

    private static func applyTapState() {
        let enabled = absorbContinuous || rewriteDiscrete
        guard enabled != tapEnabled else { return }
        tapEnabled = enabled
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: enabled)
        }
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
        let isContinuous = cgEvent.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        switch ScrollWheelPolicy.verdict(isContinuous: isContinuous, absorbContinuous: absorbContinuous, rewriteDiscrete: rewriteDiscrete) {
            case .block: return nil
            case .invertVertical: invertVerticalAxis(cgEvent)
            case .passThrough: break
        }
        return Unmanaged.passUnretained(cgEvent) // focused app will receive the event
    }

    /// Axis 1 is the vertical one. The three fields carry the same movement at different resolutions and
    /// each app reads the one it trusts, so they have to be mirrored together: flipping the line delta
    /// alone leaves pixel-precise views scrolling the old way, in the same app as everything else scrolls
    /// the new way.
    private static func invertVerticalAxis(_ cgEvent: CGEvent) {
        cgEvent.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        cgEvent.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -cgEvent.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1))
    }
}
