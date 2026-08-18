import Cocoa

/// The mouse tap behind FlickRing. Unlike Leader, the ring needs its own tap to claim a mouse button, so it
/// exists only while the module is on: no tap when disabled. Pressing the configured button opens the ring
/// under the cursor; dragging picks a sector; releasing runs the bound action off the callback (Q-16). The
/// button is reserved whole — down and up are both absorbed — so a plain click never leaks to the app.
class FlickRingEvents {
    private static var eventTap: CFMachPort?
    private static var shouldBeEnabled = false
    private static var pressOrigin: CGPoint?
    private static var currentDirection: FlickDirection?
    private static var circuitBreaker = InputTapCircuitBreaker()

    static var isEnabled: Bool {
        Preferences.flickRingEnabled && !Preferences.inputModulesSafeMode
    }

    /// Re-evaluated whenever the toggle, the safe-mode flag, or permissions change.
    static func enabledChanged() {
        let wanted = isEnabled
        if wanted {
            circuitBreaker.reset()
            createTapIfNeeded()
        }
        toggle(wanted)
        if !wanted { closeRing() }
    }

    static func disableForSafety() {
        Preferences.set("flickRingEnabled", "false", false)
        toggle(false)
        closeRing()
    }

    static func reEnableTapIfNeeded() {
        guard let eventTap, shouldBeEnabled, !CGEvent.tapIsEnabled(tap: eventTap) else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private static func toggle(_ enabled: Bool) {
        shouldBeEnabled = enabled
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: enabled)
        }
    }

    private static func createTapIfNeeded() {
        guard eventTap == nil else { return }
        let mask = [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: handleEvent,
            userInfo: nil)
        guard let eventTap else { return }
        // main thread: opening the ring and picking a sector is UI and cursor geometry, like CursorEvents
        let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        switch type {
            case .otherMouseDown: return handleDown(cgEvent)
            case .otherMouseDragged: return handleDragged(cgEvent)
            case .otherMouseUp: return handleUp(cgEvent)
            case .tapDisabledByUserInput, .tapDisabledByTimeout:
                handleTapFailure()
                return Unmanaged.passUnretained(cgEvent)
            default: return Unmanaged.passUnretained(cgEvent)
        }
    }

    private static func isConfiguredButton(_ cgEvent: CGEvent) -> Bool {
        Int(cgEvent.getIntegerValueField(.mouseEventButtonNumber)) == Preferences.flickRingButton
    }

    private static func handleDown(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard isConfiguredButton(cgEvent) else { return Unmanaged.passUnretained(cgEvent) }
        pressOrigin = cgEvent.location
        currentDirection = nil
        FlickRingPanel.show(at: cgEvent.location)
        return nil
    }

    private static func handleDragged(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard let pressOrigin else { return Unmanaged.passUnretained(cgEvent) }
        currentDirection = direction(from: pressOrigin, to: cgEvent.location)
        FlickRingPanel.highlight(currentDirection)
        return nil
    }

    private static func handleUp(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard pressOrigin != nil else { return Unmanaged.passUnretained(cgEvent) }
        let chosen = currentDirection
        closeRing()
        // Q-16: resolve here, run outside the callback
        if let chosen, let action = FlickRingBindingsStore.action(for: chosen) {
            DispatchQueue.main.async { Actions.perform(action) }
        }
        return nil
    }

    /// Screen coordinates grow downward; the pure direction logic expects +y up, so flip dy.
    private static func direction(from origin: CGPoint, to location: CGPoint) -> FlickDirection? {
        FlickRing.direction(dx: location.x - origin.x, dy: origin.y - location.y)
    }

    private static func closeRing() {
        pressOrigin = nil
        currentDirection = nil
        FlickRingPanel.hide()
    }

    private static func handleTapFailure() {
        if let eventTap, shouldBeEnabled {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        // fail closed on repeated failures instead of re-enabling forever (Q-12)
        if circuitBreaker.recordFailure(at: ProcessInfo.processInfo.systemUptime) == .trip {
            closeRing()
            DispatchQueue.main.async {
                Preferences.set("flickRingEnabled", "false", false)
                FlickRingEvents.enabledChanged()
            }
        }
    }
}
