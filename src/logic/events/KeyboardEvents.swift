import Cocoa
import IOKit.hid
import ShortcutRecorder

class KeyboardEvents {
    private static let signature = "altt".utf16.reduce(0) { ($0 << 8) + OSType($1) }
    // GetEventMonitorTarget/GetApplicationEventTarget also work, but require Accessibility Permission
    private static let shortcutEventTarget = GetEventDispatcherTarget()
    private static var eventHotKeyRefs = [String: EventHotKeyRef?]()
    private static var hotKeyPressedEventHandler: EventHandlerRef?
    private static var hotKeyReleasedEventHandler: EventHandlerRef?
    private static var panicHotKeyRef: EventHotKeyRef?
    private static var globalShortcutsAreDisabled = false
    private static var eventTap: CFMachPort?
    private static var hyperKeyHidManager: IOHIDManager?
    private static var hidSystemConnection = io_connect_t()
    private static var hyperKeyState = HyperKeyStateMachine()
    private static var hyperKeyRuntimeEnabled = false
    private static var inputTapCircuitBreaker = InputTapCircuitBreaker()
    private static let hyperKeyStateLock = NSLock()
    private static let inputTapCircuitBreakerLock = NSLock()
    private static let hyperKeyModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    private static let syntheticCapsLockMarker: Int64 = 0x414C545448595052
    private static let panicHotKeyId = UInt32.max
    private static var safetyAlertIsShowing = false
    private static var hyperKeyHoldGeneration = UInt64(0)
    private static var capsLockWasForcedOffForCurrentHold = false
    private static var capsLockStateBeforeCurrentHold: Bool?
    private static let hyperKeyHidCallback: IOHIDValueCallback = { _, _, _, value in
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad,
              IOHIDElementGetUsage(element) == 0x39 else { return }
        KeyboardEvents.handlePhysicalCapsLockChange(IOHIDValueGetIntegerValue(value) != 0)
    }

    private static let cgEventFlagsChangedHandler: CGEventTapCallBack = { _, type, cgEvent, _ in
        if cgEvent.getIntegerValueField(.eventSourceUserData) == syntheticCapsLockMarker {
            return Unmanaged.passUnretained(cgEvent)
        }
        if type == .keyDown {
            let keyCode = UInt32(cgEvent.getIntegerValueField(.keyboardEventKeycode))
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(cgEvent.flags.rawValue))
            if handleHyperKeyDown(keyCode, cgEvent) {
                return nil
            }
            if handleActiveArrowKeyIfNeeded(keyCode) {
                return nil
            }
            if shouldCancelActiveFocusOnReleaseShortcut(keyCode, modifiers) {
                DispatchQueue.main.async {
                    _ = cancelActiveFocusOnReleaseShortcutIfNeeded(keyCode, modifiers)
                }
                return nil
            }
            if shouldEnableSearchForActiveFocusOnReleaseShortcut(keyCode, modifiers) {
                DispatchQueue.main.async {
                    _ = enableSearchForActiveFocusOnReleaseShortcutIfNeeded(keyCode, modifiers)
                }
                return nil
            }
        } else if type == .keyUp {
            let keyCode = UInt32(cgEvent.getIntegerValueField(.keyboardEventKeycode))
            if handleHyperKeyUp(keyCode, cgEvent) {
                return nil
            }
        } else if type == .flagsChanged {
            let keyCode = CGKeyCode(cgEvent.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == CGKeyCode(kVK_CapsLock), hyperKeyIsActive() {
                return nil
            }
            withHyperKeyState { $0.markCapsLockUsed() }
            // TODO: it would be great to shortcut matching and trigger on the background thread
            // it would enable us to set App.shared.isBeingUsed here, and could stop tasks on main when they check the flag
            DispatchQueue.main.async {
                let modifiers = NSEvent.ModifierFlags(rawValue: UInt(cgEvent.flags.rawValue))
                // TODO: ideally, we want to absorb all modifier keys except holdShortcut
                // it was pressed down before AltTab was triggered, so we should let the up event through
                handleKeyboardEvent(nil, nil, nil, modifiers, false)
            }
        } else if (type == .tapDisabledByUserInput || type == .tapDisabledByTimeout) {
            resetHyperKeyState()
            let shouldTrip = Preferences.hyperKeyEnabled && recordInputTapFailure() == .trip
            if shouldTrip {
                setHyperKeyRuntimeEnabled(false)
                DispatchQueue.main.async {
                    disableInputModulesForSafety(NSLocalizedString("Hyper was disabled after repeated keyboard event failures.", comment: ""))
                }
            }
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        }
        // we always return this because we want to let these event pass through to the currently focused app
        return Unmanaged.passUnretained(cgEvent)
    }

    private static func handleHyperKeyDown(_ keyCode: UInt32, _ event: CGEvent) -> Bool {
        let decision = withHyperKeyState {
            $0.keyDown(keyCode, internalActionIsConfigured: false, enabled: hyperKeyRuntimeEnabled)
        }
        if decision == .systemWide {
            event.flags.formUnion(hyperKeyModifiers)
            return false
        }
        return decision == .absorb || decision == .triggerInternal
    }

    private static func handleHyperKeyUp(_ keyCode: UInt32, _ event: CGEvent) -> Bool {
        let decision = withHyperKeyState { $0.keyUp(keyCode) }
        if decision == .systemWide {
            event.flags.formUnion(hyperKeyModifiers)
        }
        return decision == .absorb
    }

    private static func handlePhysicalCapsLockChange(_ isDown: Bool) {
        let stateBeforeHold = isDown ? currentCapsLockState() : nil
        let result = withHyperKeyState { state -> (UInt64, HyperKeyCapsDecision, Bool?) in
            hyperKeyHoldGeneration &+= 1
            if isDown {
                capsLockWasForcedOffForCurrentHold = false
                capsLockStateBeforeCurrentHold = stateBeforeHold
            }
            let wasUsed = state.capsLockWasUsed
            let decision = state.capsLockChanged(
                isDown,
                at: ProcessInfo.processInfo.systemUptime,
                tapThreshold: Preferences.hyperKeyHoldDuration,
                enabled: hyperKeyRuntimeEnabled)
            let shouldRestore = !isDown && decision == .absorb && (wasUsed || capsLockWasForcedOffForCurrentHold)
            let stateToRestore = shouldRestore ? capsLockStateBeforeCurrentHold : nil
            if !isDown { capsLockStateBeforeCurrentHold = nil }
            return (hyperKeyHoldGeneration, decision, stateToRestore)
        }
        if result.1 == .toggle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { postCapsLockTap() }
        } else if let stateToRestore = result.2 {
            setCapsLockState(stateToRestore)
        } else if isDown {
            DispatchQueue.main.asyncAfter(deadline: .now() + Preferences.hyperKeyHoldDuration) {
                let shouldForceOff = withHyperKeyState { state -> Bool in
                    guard result.0 == hyperKeyHoldGeneration,
                          state.capsLockIsDown,
                          !capsLockWasForcedOffForCurrentHold else { return false }
                    capsLockWasForcedOffForCurrentHold = true
                    return true
                }
                if shouldForceOff { setCapsLockState(false) }
            }
        }
    }

    private static func postCapsLockTap() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = capsLockEvent(source, true) else { return }
        keyDown.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            capsLockEvent(source, false)?.post(tap: .cgSessionEventTap)
        }
    }

    private static func capsLockEvent(_ source: CGEventSource, _ keyDown: Bool) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_CapsLock), keyDown: keyDown) else { return nil }
        event.setIntegerValueField(.eventSourceUserData, value: syntheticCapsLockMarker)
        return event
    }

    private static func currentCapsLockState() -> Bool {
        guard openHidSystemConnectionIfNeeded() else {
            return CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        }
        var state = false
        let result = IOHIDGetModifierLockState(hidSystemConnection, Int32(kIOHIDCapsLockState), &state)
        guard result == kIOReturnSuccess else {
            Logger.error { "Unable to read Caps Lock state, status:\(result)" }
            return CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        }
        return state
    }

    private static func setCapsLockState(_ state: Bool) {
        guard openHidSystemConnectionIfNeeded() else { return }
        let result = IOHIDSetModifierLockState(hidSystemConnection, Int32(kIOHIDCapsLockState), state)
        if result != kIOReturnSuccess {
            Logger.error { "Unable to restore Caps Lock state, status:\(result)" }
        }
    }

    private static func openHidSystemConnectionIfNeeded() -> Bool {
        if hidSystemConnection != 0 { return true }
        let service = IOServiceGetMatchingService(0, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &hidSystemConnection)
        guard result == kIOReturnSuccess else {
            Logger.error { "Unable to connect to IOHIDSystem, status:\(result)" }
            hidSystemConnection = 0
            return false
        }
        return true
    }

    @discardableResult
    private static func withHyperKeyState<T>(_ body: (inout HyperKeyStateMachine) -> T) -> T {
        hyperKeyStateLock.lock()
        defer { hyperKeyStateLock.unlock() }
        return body(&hyperKeyState)
    }

    static func resetHyperKeyState() {
        let stateToRestore = withHyperKeyState { state -> Bool? in
            hyperKeyHoldGeneration &+= 1
            let stateToRestore = capsLockWasForcedOffForCurrentHold ? capsLockStateBeforeCurrentHold : nil
            capsLockWasForcedOffForCurrentHold = false
            capsLockStateBeforeCurrentHold = nil
            state.reset()
            return stateToRestore
        }
        if let stateToRestore { setCapsLockState(stateToRestore) }
    }

    static func hyperKeyEnabledChanged() {
        resetHyperKeyState()
        resetInputTapCircuitBreaker()
        guard Preferences.hyperKeyEnabled else {
            Preferences.set("hyperKeyArmingMarker", "false", false)
            setHyperKeyRuntimeEnabled(false)
            removeHyperKeyHidMonitor()
            return
        }
        Preferences.set("inputModulesSafeMode", "false", false)
        Preferences.set("hyperKeyArmingMarker", "true", false)
        guard addHyperKeyHidMonitor() else {
            disableInputModulesForSafety(NSLocalizedString("Hyper could not access the physical Caps Lock key.", comment: ""))
            return
        }
        setHyperKeyRuntimeEnabled(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard Preferences.hyperKeyEnabled, hyperKeyIsActive() else { return }
            Preferences.set("hyperKeyArmingMarker", "false", false)
        }
    }

    static func inputSafeModeChanged() {
        guard Preferences.inputModulesSafeMode else { return }
        disableInputModulesForSafety(nil)
    }

    static func stopHyperKeyMonitoring() {
        Preferences.set("hyperKeyArmingMarker", "false", false)
        setHyperKeyRuntimeEnabled(false)
        resetHyperKeyState()
        removeHyperKeyHidMonitor()
        closeHidSystemConnection()
    }

    private static func handleActiveArrowKeyIfNeeded(_ keyCode: UInt32) -> Bool {
        guard App.appIsBeingUsed, Preferences.arrowKeysEnabled, !TilesView.isSearchEditing else { return false }
        guard let direction = directionForArrowKey(keyCode) else { return false }
        DispatchQueue.main.async { App.cycleSelection(direction) }
        return true
    }

    private static func directionForArrowKey(_ keyCode: UInt32) -> Direction? {
        if keyCode == UInt32(kVK_LeftArrow) { return .left }
        if keyCode == UInt32(kVK_RightArrow) { return .right }
        if keyCode == UInt32(kVK_UpArrow) { return .up }
        if keyCode == UInt32(kVK_DownArrow) { return .down }
        return nil
    }

    static func addGlobalShortcut(_ controlId: String, _ shortcut: Shortcut) {
        addGlobalHandlerIfNeeded(shortcut)
        registerHotKeyIfNeeded(controlId, shortcut)
    }

    static func removeGlobalShortcut(_ controlId: String, _ shortcut: Shortcut) {
        unregisterHotKeyIfNeeded(controlId, shortcut)
        removeHandlerIfNeeded()
    }

    static func toggleGlobalShortcuts(_ shouldDisable: Bool) {
        if shouldDisable != globalShortcutsAreDisabled {
            let fn = shouldDisable ? unregisterHotKeyIfNeeded : registerHotKeyIfNeeded
            for shortcutId in KeyboardEventsTestable.globalShortcutsIds.keys {
                if let shortcut = ControlsTab.shortcuts[shortcutId]?.shortcut {
                    fn(shortcutId, shortcut)
                }
            }
            Logger.info { "disabled:\(shouldDisable)" }
            globalShortcutsAreDisabled = shouldDisable
        }
    }

    static func reEnableTapIfNeeded() {
        resetHyperKeyState()
        guard let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        Logger.warning { "" }
    }

    static func addEventHandlers() {
        addLocalMonitorForKeyDownAndKeyUp()
        addCgEventTapForModifierFlags()
        addPanicHotKey()
        hyperKeyEnabledChanged()
        if Preferences.recoveredInputModuleAtLaunch {
            DispatchQueue.main.async {
                showSafetyAlert(NSLocalizedString("Input extensions were disabled because AltTab+ did not finish its previous Hyper startup.", comment: ""))
            }
        }
    }

    private static func unregisterHotKeyIfNeeded(_ controlId: String, _ shortcut: Shortcut) {
        if shortcut.keyCode != .none {
            if let ref = eventHotKeyRefs[controlId] {
                UnregisterEventHotKey(ref)
                eventHotKeyRefs[controlId] = nil
            }
        }
    }

    private static func registerHotKeyIfNeeded(_ controlId: String, _ shortcut: Shortcut) {
        if shortcut.keyCode != .none {
            guard let id = KeyboardEventsTestable.globalShortcutsIds[controlId] else { return }
            if let existingReference = eventHotKeyRefs[controlId] {
                UnregisterEventHotKey(existingReference)
                eventHotKeyRefs[controlId] = nil
            }
            let hotkeyId = EventHotKeyID(signature: signature, id: UInt32(id))
            let key = shortcut.carbonKeyCode
            let mods = shortcut.carbonModifierFlags
            let options = UInt32(kEventHotKeyNoOptions)
            var shortcutsReference: EventHotKeyRef?
            let result = RegisterEventHotKey(key, mods, hotkeyId, shortcutEventTarget, options, &shortcutsReference)
            guard result == noErr, let shortcutsReference else {
                Logger.error { "Unable to register global shortcut \(controlId), status:\(result), key:\(key), modifiers:\(mods)" }
                return
            }
            eventHotKeyRefs[controlId] = shortcutsReference
        }
    }

    // TODO: handle this on a background thread?
    private static func addLocalMonitorForKeyDownAndKeyUp() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { (event: NSEvent) in
            let keyCode = event.type == .keyDown ? UInt32(event.keyCode) : nil
            let isARepeat = event.type == .keyDown ? event.isARepeat : false
            let shouldAbsorbEvent = handleKeyboardEvent(nil, nil, keyCode, event.modifierFlags, isARepeat, event)
            return shouldAbsorbEvent ? nil : event
        }
    }

    private static func addCgEventTapForModifierFlags() {
        let eventMask = [CGEventType.flagsChanged, .keyDown, .keyUp].reduce(CGEventMask(0), { $0 | (1 << $1.rawValue) })
        // CGEvent.tapCreate returns null if ensureAccessibilityCheckboxIsChecked() didn't pass
        // CGEvent.tapCreate is unaffected by SecureInput for .flagsChanged
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: cgEventFlagsChangedHandler,
            userInfo: nil)
        if let eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
            CFRunLoopAddSource(BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop, runLoopSource, .commonModes)
        } else {
            App.restart()
        }
    }

    private static func addHyperKeyHidMonitor() -> Bool {
        if hyperKeyHidManager != nil { return true }
        guard let runLoop = BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop else { return false }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ] as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(manager, hyperKeyHidCallback, nil)
        IOHIDManagerScheduleWithRunLoop(
            manager,
            runLoop,
            CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            Logger.error { "Unable to monitor the physical Caps Lock key, status:\(result)" }
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                runLoop,
                CFRunLoopMode.commonModes.rawValue)
            return false
        }
        hyperKeyHidManager = manager
        return true
    }

    private static func removeHyperKeyHidMonitor() {
        guard let manager = hyperKeyHidManager else { return }
        if let runLoop = BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                runLoop,
                CFRunLoopMode.commonModes.rawValue)
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hyperKeyHidManager = nil
    }

    private static func closeHidSystemConnection() {
        guard hidSystemConnection != 0 else { return }
        IOServiceClose(hidSystemConnection)
        hidSystemConnection = 0
    }

    private static func addGlobalHandlerIfNeeded(_ shortcut: Shortcut) {
        guard shortcut.keyCode != .none else { return }
        addGlobalHandlersIfNeeded()
    }

    private static func addGlobalHandlersIfNeeded() {
        if hotKeyPressedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
            InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                if id.id == KeyboardEvents.panicHotKeyId {
                    DispatchQueue.main.async {
                        KeyboardEvents.disableInputModulesForSafety(NSLocalizedString("The emergency shortcut disabled all AltTab+ input extensions.", comment: ""))
                    }
                    return noErr
                }
                handleKeyboardEvent(Int(id.id), .down, nil, nil, false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyPressedEventHandler)
        }
        if hotKeyReleasedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))]
            InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                if id.id == KeyboardEvents.panicHotKeyId { return noErr }
                handleKeyboardEvent(Int(id.id), .up, nil, nil, false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyReleasedEventHandler)
        }
    }

    private static func addPanicHotKey() {
        addGlobalHandlersIfNeeded()
        let hotkeyId = EventHotKeyID(signature: signature, id: panicHotKeyId)
        let modifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        let result = RegisterEventHotKey(UInt32(kVK_Escape), modifiers, hotkeyId, shortcutEventTarget, 0, &panicHotKeyRef)
        guard result == noErr else {
            Logger.error { "Unable to register emergency input shortcut, status:\(result)" }
            return
        }
    }

    private static func removeHandlerIfNeeded() {
        let globalShortcuts = ControlsTab.shortcuts.values.filter { $0.scope == .global }
        if let hotKeyPressedEventHandler_ = hotKeyPressedEventHandler, let hotKeyReleasedEventHandler_ = hotKeyReleasedEventHandler,
           panicHotKeyRef == nil,
           (globalShortcuts.allSatisfy { $0.shortcut.keyCode == .none }) {
            RemoveEventHandler(hotKeyPressedEventHandler_)
            hotKeyPressedEventHandler = nil
            RemoveEventHandler(hotKeyReleasedEventHandler_)
            hotKeyReleasedEventHandler = nil
        }
    }

    private static func hyperKeyIsActive() -> Bool {
        withHyperKeyState { _ in hyperKeyRuntimeEnabled }
    }

    private static func setHyperKeyRuntimeEnabled(_ enabled: Bool) {
        withHyperKeyState {
            hyperKeyRuntimeEnabled = enabled
            if !enabled { $0.reset() }
        }
    }

    private static func recordInputTapFailure() -> InputTapRecoveryDecision {
        inputTapCircuitBreakerLock.lock()
        defer { inputTapCircuitBreakerLock.unlock() }
        return inputTapCircuitBreaker.recordFailure(at: ProcessInfo.processInfo.systemUptime)
    }

    private static func resetInputTapCircuitBreaker() {
        inputTapCircuitBreakerLock.lock()
        inputTapCircuitBreaker.reset()
        inputTapCircuitBreakerLock.unlock()
    }

    private static func disableInputModulesForSafety(_ message: String?) {
        Preferences.set("inputModulesSafeMode", "true", false)
        Preferences.set("hyperKeyEnabled", "false", false)
        Preferences.set("hyperKeyArmingMarker", "false", false)
        Preferences.set("nextWindowGesture", GesturePreference.disabled.indexAsString, false)
        setHyperKeyRuntimeEnabled(false)
        removeHyperKeyHidMonitor()
        TrackpadEvents.disableForSafety()
        ScrollwheelEvents.disableForSafety()
        App.hideUi()
        if let message { showSafetyAlert(message) }
    }

    private static func showSafetyAlert(_ message: String) {
        guard !safetyAlertIsShowing else { return }
        safetyAlertIsShowing = true
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("AltTab+ input safety", comment: "")
        alert.informativeText = message
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
        safetyAlertIsShowing = false
    }
}
