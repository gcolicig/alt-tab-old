import Cocoa
import ShortcutRecorder

/// Takes system shortcuts over for AltTab+ actions and gives them back.
///
/// A symbolic hotkey stays disabled after AltTab+ quits, so ownership is persisted: the state a hotkey
/// had before AltTab+ touched it is stored, and it is restored as soon as the matching AltTab+ shortcut
/// is unassigned, or at the next launch if the app was killed in between. AltTab+ therefore never leaves
/// a system shortcut disabled that it did not disable itself.
///
/// Which hotkey belongs to which combination is read from the system rather than hardcoded, because
/// several ids can share one combination and their meaning differs between macOS versions.
enum NativeSystemShortcuts {
    private static let scannedIds = 0...400
    private static let ownershipKey = "ownedSystemHotkeys"
    private static let comparedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
    /// handled by `ControlsTab.toggleNativeCommandTabIfNeeded`, which owns the switcher combinations
    private static let excludedIds = Set(CGSSymbolicHotKey.allCases.map(\.rawValue))

    private static let systemHotkeys: [Int: Shortcut] = {
        var hotkeys = [Int: Shortcut]()
        scannedIds.forEach { hotkeyId in
            guard !excludedIds.contains(hotkeyId) else { return }
            var options = UInt32(0), keyCode = UInt32(0), modifiers = UInt32(0)
            guard CGSGetSymbolicHotKeyValue(hotkeyId, &options, &keyCode, &modifiers) == .success,
                  keyCode != 0xFFFF, let code = KeyCode(rawValue: CGKeyCode(keyCode)) else { return }
            let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers)).intersection(comparedModifiers)
            hotkeys[hotkeyId] = Shortcut(code: code, modifierFlags: flags, characters: nil, charactersIgnoringModifiers: nil)
        }
        return hotkeys
    }()

    static func apply() {
        let assigned = ControlsTab.shortcuts.values
            .filter { $0.scope == .global && $0.shortcut.keyCode != .none }
            .map { $0.shortcut }
        systemHotkeys.forEach { hotkeyId, hotkeyShortcut in
            let isClaimed = assigned.contains { matches(hotkeyShortcut, $0) }
            if isClaimed {
                takeOver(hotkeyId)
            } else {
                release(hotkeyId)
            }
        }
    }

    /// Called at launch before any shortcut is registered, so a hotkey disabled by a killed AltTab+ is
    /// restored even when the user meanwhile removed the shortcut that caused the takeover.
    static func releaseAbandonedOwnership() {
        ownership().keys.compactMap(Int.init).forEach { release($0) }
    }

    private static func matches(_ hotkeyShortcut: Shortcut, _ assigned: Shortcut) -> Bool {
        hotkeyShortcut.keyCode == assigned.keyCode
            && hotkeyShortcut.modifierFlags == assigned.modifierFlags.intersection(comparedModifiers)
    }

    private static func takeOver(_ hotkeyId: Int) {
        guard ownership()[String(hotkeyId)] == nil else { return }
        let wasEnabled = CGSIsSymbolicHotKeyEnabled(hotkeyId)
        setOwnership(hotkeyId, wasEnabled)
        guard wasEnabled else { return }
        setEnabled(hotkeyId, false)
    }

    private static func release(_ hotkeyId: Int) {
        guard let wasEnabled = ownership()[String(hotkeyId)] else { return }
        if wasEnabled {
            setEnabled(hotkeyId, true)
        }
        setOwnership(hotkeyId, nil)
    }

    private static func setEnabled(_ hotkeyId: Int, _ isEnabled: Bool) {
        guard CGSSetSymbolicHotKeyEnabled(hotkeyId, isEnabled) != .success else { return }
        Logger.warning { "could not set symbolic hotkey \(hotkeyId) through the window server; writing preferences" }
        writeSymbolicHotKeyPreference(hotkeyId, isEnabled)
        TransientNotice.show(NSLocalizedString("A keyboard shortcut was changed in the system preferences. Restart the Dock or log in again for it to take effect.", comment: ""))
    }

    /// Fallback when the window server refuses the change. It only takes effect after the Dock reloads,
    /// which is why the caller shows a notice.
    private static func writeSymbolicHotKeyPreference(_ hotkeyId: Int, _ isEnabled: Bool) {
        let domain = "com.apple.symbolichotkeys" as CFString
        let key = "AppleSymbolicHotKeys" as CFString
        var hotkeys = (CFPreferencesCopyAppValue(key, domain) as? [String: Any]) ?? [:]
        var entry = (hotkeys[String(hotkeyId)] as? [String: Any]) ?? [:]
        entry["enabled"] = isEnabled
        hotkeys[String(hotkeyId)] = entry
        CFPreferencesSetAppValue(key, hotkeys as CFDictionary, domain)
        CFPreferencesAppSynchronize(domain)
    }

    private static func ownership() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: ownershipKey) as? [String: Bool] ?? [:]
    }

    private static func setOwnership(_ hotkeyId: Int, _ previousState: Bool?) {
        var owned = ownership()
        owned[String(hotkeyId)] = previousState
        UserDefaults.standard.set(owned, forKey: ownershipKey)
    }
}
