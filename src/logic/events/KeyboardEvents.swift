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
    private static var globalShortcutsAreDisabled = false
    private static var eventTap: CFMachPort?
    private static var hyperKeyHidManager: IOHIDManager?
    private static var hyperKeyState = HyperKeyStateMachine()
    private static let hyperKeyStateLock = NSLock()
    private static let hyperKeyModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    private static let syntheticCapsLockMarker: Int64 = 0x414C545448595052
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
            if keyCode == CGKeyCode(kVK_CapsLock), Preferences.hyperKeyEnabled {
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
            CGEvent.tapEnable(tap: eventTap!, enable: true)
        }
        // we always return this because we want to let these event pass through to the currently focused app
        return Unmanaged.passUnretained(cgEvent)
    }

    private static func handleHyperKeyDown(_ keyCode: UInt32, _ event: CGEvent) -> Bool {
        let action = hyperKeyAction(keyCode)
        let internalActionIsConfigured = action != .none && !App.appIsBeingUsed
        let decision = withHyperKeyState {
            $0.keyDown(keyCode, internalActionIsConfigured: internalActionIsConfigured, enabled: Preferences.hyperKeyEnabled)
        }
        if decision == .systemWide {
            event.flags.formUnion(hyperKeyModifiers)
            return false
        }
        if decision == .triggerInternal, let windowLayoutAction = action.windowLayoutAction {
            DispatchQueue.main.async {
                WindowLayouts.perform(windowLayoutAction)
            }
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
        let decision = withHyperKeyState {
            $0.capsLockChanged(
                isDown,
                at: ProcessInfo.processInfo.systemUptime,
                tapThreshold: Preferences.hyperKeyHoldDuration,
                enabled: Preferences.hyperKeyEnabled)
        }
        if decision == .toggle {
            postCapsLockTap()
        }
    }

    private static func postCapsLockTap() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        [true, false].forEach {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_CapsLock), keyDown: $0) else { return }
            event.setIntegerValueField(.eventSourceUserData, value: syntheticCapsLockMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private static func hyperKeyAction(_ keyCode: UInt32) -> HyperKeyActionPreference {
        switch Int(keyCode) {
        case kVK_LeftArrow: return Preferences.hyperKeyLeftAction
        case kVK_RightArrow: return Preferences.hyperKeyRightAction
        case kVK_UpArrow: return Preferences.hyperKeyUpAction
        case kVK_DownArrow: return Preferences.hyperKeyDownAction
        default: return .none
        }
    }

    @discardableResult
    private static func withHyperKeyState<T>(_ body: (inout HyperKeyStateMachine) -> T) -> T {
        hyperKeyStateLock.lock()
        defer { hyperKeyStateLock.unlock() }
        return body(&hyperKeyState)
    }

    static func resetHyperKeyState() {
        withHyperKeyState { $0.reset() }
    }

    static func hyperKeyEnabledChanged() {
        resetHyperKeyState()
        Preferences.hyperKeyEnabled ? addHyperKeyHidMonitor() : removeHyperKeyHidMonitor()
    }

    static func stopHyperKeyMonitoring() {
        resetHyperKeyState()
        removeHyperKeyHidMonitor()
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
        hyperKeyEnabledChanged()
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

    private static func addHyperKeyHidMonitor() {
        guard hyperKeyHidManager == nil,
              let runLoop = BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop else { return }
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
            return
        }
        hyperKeyHidManager = manager
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

    private static func addGlobalHandlerIfNeeded(_ shortcut: Shortcut) {
        if shortcut.keyCode != .none && hotKeyPressedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
            InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                handleKeyboardEvent(Int(id.id), .down, nil, nil, false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyPressedEventHandler)
        }
        if shortcut.keyCode != .none && hotKeyReleasedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))]
            InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                handleKeyboardEvent(Int(id.id), .up, nil, nil, false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyReleasedEventHandler)
        }
    }

    private static func removeHandlerIfNeeded() {
        let globalShortcuts = ControlsTab.shortcuts.values.filter { $0.scope == .global }
        if let hotKeyPressedEventHandler_ = hotKeyPressedEventHandler, let hotKeyReleasedEventHandler_ = hotKeyReleasedEventHandler,
           (globalShortcuts.allSatisfy { $0.shortcut.keyCode == .none }) {
            RemoveEventHandler(hotKeyPressedEventHandler_)
            hotKeyPressedEventHandler = nil
            RemoveEventHandler(hotKeyReleasedEventHandler_)
            hotKeyReleasedEventHandler = nil
        }
    }
}
