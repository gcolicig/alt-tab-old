import Carbon.HIToolbox.Events
import ShortcutRecorder

class KeyboardEventsTestable {
    /// The block boundaries are hoisted into typed constants rather than repeated inline. Spelling the same
    /// multi-term sum out at every use made the type checker exceed the 250ms limit the build enforces as
    /// an error. The assigned ids are unchanged; the uniqueness tests cover that.
    static var globalShortcutsIds: [String: Int] {
        let shortcutCount: Int = Preferences.maxShortcutCount
        let afterHoldShortcuts: Int = shortcutCount * 2
        let afterLayouts: Int = afterHoldShortcuts + WindowLayoutAction.allCases.count
        let afterDisplayMoves: Int = afterLayouts + DisplayMoveAction.allCases.count
        let afterSpaceActions: Int = afterDisplayMoves + SpaceAction.all.count
        let afterLaunchApps: Int = afterSpaceActions + Preferences.maxLaunchAppCount
        var ids = [String: Int]()
        (0..<shortcutCount).forEach { ids[Preferences.indexToName("nextWindowShortcut", $0)] = $0 }
        (0..<shortcutCount).forEach { ids[Preferences.indexToName("holdShortcut", $0)] = shortcutCount + $0 }
        WindowLayoutAction.allCases.enumerated().forEach {
            ids[$0.element.shortcutPreferenceKey] = afterHoldShortcuts + $0.offset
        }
        DisplayMoveAction.allCases.enumerated().forEach {
            ids[$0.element.shortcutPreferenceKey] = afterLayouts + $0.offset
        }
        SpaceAction.all.enumerated().forEach {
            ids[$0.element.shortcutPreferenceKey] = afterDisplayMoves + $0.offset
        }
        (0..<Preferences.maxLaunchAppCount).forEach {
            ids[LaunchAppAction.shortcutPreferenceKey($0)] = afterSpaceActions + $0
        }
        (0..<Preferences.maxOpenUrlCount).forEach {
            ids[OpenUrlAction.shortcutPreferenceKey($0)] = afterLaunchApps + $0
        }
        return ids
    }
}

enum HyperKeyDecision: Equatable {
    case pass
    case absorb
    case systemWide
    case triggerInternal
}

enum HyperKeyCapsDecision: Equatable {
    case pass
    case absorb
    case toggle
}

private enum HyperKeyRoute {
    case systemWide
    case internalAction
}

struct HyperKeyStateMachine {
    private(set) var capsLockIsDown = false
    private(set) var capsLockWasUsed = false
    private var routedKeyCodes = [UInt32: HyperKeyRoute]()
    private var capsLockPressedAt: TimeInterval?

    mutating func capsLockChanged(_ isDown: Bool, at timestamp: TimeInterval, tapThreshold: TimeInterval, enabled: Bool) -> HyperKeyCapsDecision {
        guard enabled else {
            reset()
            return .pass
        }
        if isDown {
            guard !capsLockIsDown else { return .absorb }
            capsLockIsDown = true
            capsLockWasUsed = false
            capsLockPressedAt = timestamp
            return .absorb
        }
        guard capsLockIsDown else { return .absorb }
        let shouldToggle = !capsLockWasUsed && timestamp - (capsLockPressedAt ?? timestamp) < tapThreshold
        capsLockIsDown = false
        capsLockWasUsed = false
        capsLockPressedAt = nil
        return shouldToggle ? .toggle : .absorb
    }

    mutating func keyDown(_ keyCode: UInt32, internalActionIsConfigured: Bool, enabled: Bool, isAutorepeat: Bool = false) -> HyperKeyDecision {
        guard enabled else {
            reset()
            return .pass
        }
        if let route = routedKeyCodes[keyCode] {
            // a route outlives its key-up when the event tap misses it, for example while secure input is active.
            // a fresh press with Caps Lock up therefore means the route is stale and must not modify the key.
            guard capsLockIsDown || isAutorepeat else {
                routedKeyCodes.removeValue(forKey: keyCode)
                return .pass
            }
            return route == .systemWide ? .systemWide : .absorb
        }
        guard capsLockIsDown else { return .pass }
        capsLockWasUsed = true
        let route: HyperKeyRoute = internalActionIsConfigured ? .internalAction : .systemWide
        routedKeyCodes[keyCode] = route
        return route == .systemWide ? .systemWide : .triggerInternal
    }

    mutating func keyUp(_ keyCode: UInt32) -> HyperKeyDecision {
        guard let route = routedKeyCodes.removeValue(forKey: keyCode) else { return .pass }
        return route == .systemWide ? .systemWide : .absorb
    }

    mutating func markCapsLockUsed() {
        if capsLockIsDown {
            capsLockWasUsed = true
        }
    }

    mutating func reset() {
        capsLockIsDown = false
        capsLockWasUsed = false
        capsLockPressedAt = nil
        routedKeyCodes.removeAll()
    }
}

enum InputTapRecoveryDecision: Equatable {
    case recover
    case trip
}

struct InputTapCircuitBreaker {
    private var failures = [TimeInterval]()

    mutating func recordFailure(at timestamp: TimeInterval, window: TimeInterval = 10, threshold: Int = 2) -> InputTapRecoveryDecision {
        failures.removeAll { timestamp - $0 > window }
        failures.append(timestamp)
        if failures.count >= threshold {
            failures.removeAll()
            return .trip
        }
        return .recover
    }

    mutating func reset() {
        failures.removeAll()
    }
}

func cancelActiveFocusOnReleaseShortcutIfNeeded(_ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?) -> Bool {
    guard shouldCancelActiveFocusOnReleaseShortcut(keyCode, modifiers) else { return false }
    App.forceDoNothingOnRelease = true
    App.hideUi()
    return true
}

func shouldCancelActiveFocusOnReleaseShortcut(_ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?) -> Bool {
    keyCode == UInt32(kVK_Escape) && activeFocusOnReleaseShortcutHoldIsPressed(modifiers)
}

func enableSearchForActiveFocusOnReleaseShortcutIfNeeded(_ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?) -> Bool {
    guard shouldEnableSearchForActiveFocusOnReleaseShortcut(keyCode, modifiers) else { return false }
    TilesView.enableSearchEditing()
    return true
}

func shouldEnableSearchForActiveFocusOnReleaseShortcut(_ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?) -> Bool {
    keyCode == UInt32(kVK_ISO_Section) && activeFocusOnReleaseShortcutHoldIsPressed(modifiers)
}

private func activeFocusOnReleaseShortcutHoldIsPressed(_ modifiers: NSEvent.ModifierFlags?) -> Bool {
    guard App.appIsBeingUsed,
          Preferences.shortcutStyle == .focusOnRelease,
          App.shortcutIndex == 0 || App.shortcutIndex == 1,
          let holdShortcut = ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", App.shortcutIndex)] else {
        return false
    }
    return modifiersContainHoldShortcut(modifiers, holdShortcut)
}

private func modifiersContainHoldShortcut(_ modifiers: NSEvent.ModifierFlags?, _ holdShortcut: ATShortcut) -> Bool {
    let currentModifiers = cocoaToCarbonFlags(modifiers ?? ModifierFlags.current).cleaned()
    let holdModifiers = holdShortcut.shortcut.carbonModifierFlags.cleaned()
    return currentModifiers == (currentModifiers | holdModifiers)
}

@discardableResult
func handleKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool, _ event: NSEvent? = nil) -> Bool {
    if cancelActiveFocusOnReleaseShortcutIfNeeded(keyCode, modifiers) {
        return true
    }
    if enableSearchForActiveFocusOnReleaseShortcutIfNeeded(keyCode, modifiers) {
        return true
    }
    if let event, shouldAbsorbSearchEditingKeyDown(event) {
        switch TilesView.handleSearchEditingKeyDown(event) {
        case .handled: return true
        case .passToField: return false
        case .passToShortcuts: break
        }
    }
    logKeyboardEvent(globalId, shortcutState, keyCode, modifiers, isARepeat)
    let someShortcutTriggered = triggerMatchingShortcuts(globalId, shortcutState, keyCode, modifiers, isARepeat)
    return someShortcutTriggered
}

private func logKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) {
    if let globalId, let shortcutState {
        Logger.debug {
            let shortcut = KeyboardEventsTestable.globalShortcutsIds.first { $0.value == globalId }
            return "globalShortcut:\(shortcut?.key ?? "") state:\(shortcutState)"
        }
        return
    }
    // TODO: use proper pattern from SwiftBeaver to not compute SymbolicModifierFlagsTransformer when logs are off
    Logger.debug {
        let modifiersAsString = modifiers.flatMap { SymbolicModifierFlagsTransformer.shared.transformedValue(NSNumber(value: $0.rawValue)) }
        let keyCodeAsString = keyCode.flatMap { SymbolicKeyCodeTransformer.shared.transformedValue(NSNumber(value: $0)) }
        return "keys:\(modifiersAsString ?? "")\(keyCodeAsString ?? "") isARepeat:\(isARepeat)"
    }
}

private func shouldAbsorbSearchEditingKeyDown(_ event: NSEvent?) -> Bool {
    guard let event, event.type == .keyDown, App.appIsBeingUsed, TilesPanel.shared.isKeyWindow, TilesView.isSearchEditing else {
        return false
    }
    return true
}

private func triggerMatchingShortcuts(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) -> Bool {
    var someShortcutTriggered = false
    for shortcut in ControlsTab.shortcuts.values {
        if shortcut.matches(globalId, shortcutState, keyCode, modifiers) && shortcut.shouldTrigger() {
            shortcut.executeAction(isARepeat)
            // we want to pass-through alt-up to the active app, since it saw alt-down previously
            if !shortcut.id.starts(with: "holdShortcut") {
                someShortcutTriggered = true
            }
        }
        shortcut.redundantSafetyMeasures()
    }
    // TODO if we manage to move all keyboard listening to the background thread, we'll have issues returning this boolean
    // this function uses many objects that are also used on the main-thread. It also executes the actions
    // we'll have to rework this whole approach. Today we rely on somewhat in-order events/actions
    // special attention should be given to App.appIsBeingUsed which is being set to true when executing the nextWindowShortcut action
    return someShortcutTriggered
}
