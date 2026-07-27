import Carbon.HIToolbox.Events
import XCTest

final class KeyboardEventsUtilsTests: XCTestCase {
    func testShortCapsLockTapTogglesCapsLock() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.capsLockChanged(false, at: 1.1, tapThreshold: 0.2, enabled: true), .toggle)
    }

    func testLongCapsLockHoldDoesNotToggleCapsLock() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.capsLockChanged(false, at: 1.21, tapThreshold: 0.2, enabled: true), .absorb)
    }

    func testCapsLockTapDoesNotToggleAfterAnotherModifierWasPressed() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        state.markCapsLockUsed()
        XCTAssertEqual(state.capsLockChanged(false, at: 1.1, tapThreshold: 0.2, enabled: true), .absorb)
    }

    func testDuplicateCapsLockEventsDoNotToggleTwice() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.capsLockChanged(true, at: 1.01, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.capsLockChanged(false, at: 1.1, tapThreshold: 0.2, enabled: true), .toggle)
        XCTAssertEqual(state.capsLockChanged(false, at: 1.11, tapThreshold: 0.2, enabled: true), .absorb)
    }

    func testHyperKeyRoutesUnconfiguredKeysSystemWide() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.keyDown(UInt32(kVK_ANSI_T), internalActionIsConfigured: false, enabled: true), .systemWide)
        XCTAssertEqual(state.keyDown(UInt32(kVK_ANSI_T), internalActionIsConfigured: false, enabled: true), .systemWide)
        XCTAssertEqual(state.capsLockChanged(false, at: 1.1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.keyUp(UInt32(kVK_ANSI_T)), .systemWide)
        XCTAssertEqual(state.keyUp(UInt32(kVK_ANSI_T)), .pass)
    }

    func testHyperKeyRoutesConfiguredInternalActionAndAbsorbsKeyPair() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.keyDown(UInt32(kVK_LeftArrow), internalActionIsConfigured: true, enabled: true), .triggerInternal)
        XCTAssertEqual(state.keyDown(UInt32(kVK_LeftArrow), internalActionIsConfigured: true, enabled: true), .absorb)
        XCTAssertEqual(state.keyUp(UInt32(kVK_LeftArrow)), .absorb)
        XCTAssertEqual(state.capsLockChanged(false, at: 1.1, tapThreshold: 0.2, enabled: true), .absorb)
    }

    func testHyperKeyPassesKeysWhileCapsLockIsUp() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.keyDown(UInt32(kVK_LeftArrow), internalActionIsConfigured: true, enabled: true), .pass)
        XCTAssertEqual(state.keyUp(UInt32(kVK_LeftArrow)), .pass)
    }

    func testHyperKeyDisableClearsState() {
        var state = HyperKeyStateMachine()
        XCTAssertEqual(state.capsLockChanged(true, at: 1, tapThreshold: 0.2, enabled: true), .absorb)
        XCTAssertEqual(state.keyDown(UInt32(kVK_UpArrow), internalActionIsConfigured: true, enabled: true), .triggerInternal)
        XCTAssertEqual(state.keyDown(UInt32(kVK_UpArrow), internalActionIsConfigured: true, enabled: false), .pass)
        XCTAssertFalse(state.capsLockIsDown)
        XCTAssertEqual(state.keyUp(UInt32(kVK_UpArrow)), .pass)
    }

    func testInputTapCircuitBreakerTripsOnSecondRecentFailure() {
        var circuitBreaker = InputTapCircuitBreaker()
        XCTAssertEqual(circuitBreaker.recordFailure(at: 1), .recover)
        XCTAssertEqual(circuitBreaker.recordFailure(at: 5), .trip)
    }

    func testInputTapCircuitBreakerForgetsOldFailures() {
        var circuitBreaker = InputTapCircuitBreaker()
        XCTAssertEqual(circuitBreaker.recordFailure(at: 1), .recover)
        XCTAssertEqual(circuitBreaker.recordFailure(at: 12), .recover)
    }

    func testInputTapCircuitBreakerResetClearsFailures() {
        var circuitBreaker = InputTapCircuitBreaker()
        XCTAssertEqual(circuitBreaker.recordFailure(at: 1), .recover)
        circuitBreaker.reset()
        XCTAssertEqual(circuitBreaker.recordFailure(at: 2), .recover)
    }

    // alt-down > tab-down > tab-up > alt-up
    func testMostCommonSequence() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    // alt-down > tab-down > alt-up > tab-up
    func testSecondMostCommonSequence() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    // alt-down > tab-down > alt-up > tab-up
    func testSecondMostCommonSequenceVariation() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    // alt-down > alt-up > nextWindowShortcut-down
    // under heavy stress, macOS may miss sending us events
    // we poll NSEvent.modifierFlags to try to see if modifiers are up
    func testSequenceWithMissingEventAndWeCanSaveTheDay() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    // alt-down > alt-up > nextWindowShortcut-down
    // under heavy stress, macOS may miss sending us events
    // we poll NSEvent.modifierFlags to try to see if modifiers are up
    func testSequenceWithMissingEventAndWeCanNotSaveTheDay() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
    }

    // alt-down > alt-up > nextWindowShortcut-down > nextWindowShortcut-up
    func testOutOfOrderEvents() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        ModifierFlags.current = [.option]
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    // alt-down > tab-down > tab-up > w-down > w-up > alt-up
    func testCloseWindowShortcut() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(nil, nil, keycodeMap["w"], [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "closeWindowShortcut"])
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "closeWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "closeWindowShortcut", "holdShortcut"])
    }

    func testOnReleaseDoNothing() throws {
        resetState()
        Preferences.shortcutStyle = .doNothingOnRelease
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
    }

    func testOnReleaseToggleSearchModeDoesNotFocus() throws {
        resetState()
        Preferences.shortcutStyle = .searchOnRelease
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
    }

    func testEscapeCancelsFocusOnReleaseForFirstShortcut() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])

        XCTAssertTrue(handleKeyboardEvent(nil, nil, UInt32(kVK_Escape), [.option], false))
        XCTAssertFalse(App.appIsBeingUsed)
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
    }

    func testEscapeCancelsFocusOnReleaseForSecondShortcut() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut2"], .down, nil, nil, false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut2"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut2"])

        XCTAssertTrue(handleKeyboardEvent(nil, nil, UInt32(kVK_Escape), [.option], false))
        XCTAssertFalse(App.appIsBeingUsed)
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut2"])
    }

    func testEscapeDoesNotCancelIfConfiguredHoldShortcutIsNotPressed() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)

        XCTAssertFalse(shouldCancelActiveFocusOnReleaseShortcut(UInt32(kVK_Escape), []))
        XCTAssertTrue(App.appIsBeingUsed)
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    func testIsoSectionEnablesSearchForFirstFocusOnReleaseShortcut() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)

        XCTAssertTrue(handleKeyboardEvent(nil, nil, UInt32(kVK_ISO_Section), [.option], false))
        XCTAssertTrue(TilesView.isSearchEditing)
        XCTAssertTrue(App.forceDoNothingOnRelease)
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
    }

    func testIsoSectionEnablesSearchForSecondFocusOnReleaseShortcut() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut2"], .down, nil, nil, false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut2"], .up, nil, nil, false)

        XCTAssertTrue(handleKeyboardEvent(nil, nil, UInt32(kVK_ISO_Section), [.option], false))
        XCTAssertTrue(TilesView.isSearchEditing)
        XCTAssertTrue(App.forceDoNothingOnRelease)
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut2"])
    }

    func testIsoSectionDoesNotEnableSearchIfConfiguredHoldShortcutIsNotPressed() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)

        XCTAssertFalse(shouldEnableSearchForActiveFocusOnReleaseShortcut(UInt32(kVK_ISO_Section), []))
        XCTAssertFalse(TilesView.isSearchEditing)
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "holdShortcut"])
    }

    // alt-down > tab-down > tab-up > `-down > `-up
    func testTransitionFromOneShortcutToAnother() throws {
        resetState()
        ModifierFlags.current = [.option]
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, [])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .down, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(KeyboardEventsTestable.globalShortcutsIds["nextWindowShortcut"], .up, nil, nil, false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut"])
        handleKeyboardEvent(nil, nil, keycodeMap["`"], [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "nextWindowShortcut2"])
        handleKeyboardEvent(nil, nil, nil, [.option], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "nextWindowShortcut2"])
        ModifierFlags.current = []
        handleKeyboardEvent(nil, nil, nil, [], false)
        XCTAssertEqual(ControlsTab.shortcutsActionsTriggered, ["nextWindowShortcut", "nextWindowShortcut2", "holdShortcut2"])
    }

    private func resetState() {
        App.app.appIsBeingUsed = false
        App.app.shortcutIndex = 0
        App.app.forceDoNothingOnRelease = false
        TilesView.isSearchEditing = false
        Preferences.shortcutStyle = .focusOnRelease
        ControlsTab.shortcuts.values.forEach { $0.state = .up }
        ControlsTab.shortcutsActionsTriggered = []
    }

    private let keycodeMap: [Character: UInt32] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03,
        "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
        "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
        "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
        "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
        "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C,
        "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
        "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25,
        "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
        "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D,
        "m": 0x2E, ".": 0x2F, "`": 0x32, " ": 0x31
    ]
}
