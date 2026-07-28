import Cocoa
import ShortcutRecorder

/// Takes system shortcuts over for AltTab+ actions and gives them back.
///
/// A symbolic hotkey stays disabled after AltTab+ quits, so ownership is persisted: the state a hotkey
/// had before AltTab+ touched it is stored, and it is restored as soon as the matching AltTab+ shortcut
/// is unassigned, or at the next launch if the app was killed in between. AltTab+ therefore never leaves
/// a system shortcut disabled that it did not disable itself.
enum NativeSystemShortcuts {
    /// `Switch to Desktop 1` to `Switch to Desktop 10`, in the order of `SpaceAction.all` digits.
    private static let spaceHotkeyIds = Array(118...127)
    private static let ownershipKey = "ownedSystemHotkeys"

    static func apply() {
        let assignedDigits = Set(SpaceAction.all.compactMap { action -> Int? in
            guard let shortcut = ControlsTab.shortcuts[action.shortcutPreferenceKey]?.shortcut,
                  let digit = controlDigit(of: shortcut) else { return nil }
            return digit
        })
        spaceHotkeyIds.enumerated().forEach { offset, hotkeyId in
            // id 118 is digit 1, id 127 is digit 0
            let digit = offset == 9 ? 0 : offset + 1
            if assignedDigits.contains(digit) {
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

    private static func controlDigit(of shortcut: Shortcut) -> Int? {
        guard shortcut.modifierFlags == NSEvent.ModifierFlags.control else { return nil }
        guard let characters = shortcut.charactersIgnoringModifiers ?? shortcut.characters,
              characters.count == 1, let digit = Int(characters) else { return nil }
        return digit
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
