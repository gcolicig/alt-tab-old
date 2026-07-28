import Cocoa

/// A named set of shortcut assignments that the user applies and removes in one step.
///
/// AltTab+ ships without assigned module shortcuts, because the combinations worth having are usually
/// already taken on the target machines. A preset makes the useful set available as a decision instead
/// of as a default, and it removes exactly what it assigned: an entry the user changed afterwards stays
/// untouched.
struct ShortcutPreset {
    let id: String
    let title: String
    let summary: String
    /// preference key to key equivalent, in the notation of `Shortcut(keyEquivalent:)`
    let assignments: [(key: String, keyEquivalent: String)]

    var isApplied: Bool {
        assignments.allSatisfy { assignment in
            Preferences.shortcut(assignment.key) == Preferences.shortcutFromKeyEquivalent(assignment.keyEquivalent)
        }
    }

    /// Preference keys that already carry a different shortcut. They are reported rather than
    /// overwritten, so applying a preset can never silently take a shortcut away.
    func occupiedKeys() -> [String] {
        assignments.compactMap { assignment in
            guard let existing = Preferences.shortcut(assignment.key),
                  existing != Preferences.shortcutFromKeyEquivalent(assignment.keyEquivalent) else { return nil }
            return assignment.key
        }
    }

    func apply() {
        let occupied = Set(occupiedKeys())
        assignments.filter { !occupied.contains($0.key) }.forEach {
            Preferences.setShortcut($0.key, keyEquivalent: $0.keyEquivalent)
        }
        NativeSystemShortcuts.apply()
    }

    func remove() {
        assignments.forEach { assignment in
            guard Preferences.shortcut(assignment.key) == Preferences.shortcutFromKeyEquivalent(assignment.keyEquivalent) else { return }
            Preferences.setShortcut(assignment.key, keyEquivalent: "")
        }
        NativeSystemShortcuts.apply()
    }
}

enum ShortcutPresets {
    /// Mirrors the macOS layout for Spaces. macOS owns `Control` plus a digit for `Switch to Desktop`,
    /// so applying this preset also hands those system shortcuts to AltTab+ until the preset is removed.
    static let macOsSpaces = ShortcutPreset(
        id: "macOsSpaces",
        title: NSLocalizedString("macOS Spaces shortcuts", comment: ""),
        summary: NSLocalizedString("Control plus 1 to 9 switches to that Space, Control plus 0 toggles back to the last one. The matching system shortcuts are disabled while this is assigned, and restored when it is removed.", comment: ""),
        assignments: SpaceAction.all
            .filter { !$0.presetKeyEquivalent.isEmpty }
            .map { (key: $0.shortcutPreferenceKey, keyEquivalent: $0.presetKeyEquivalent) })

    static let all = [macOsSpaces]
}
