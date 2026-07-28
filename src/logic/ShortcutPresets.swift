import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

/// A named set of shortcut assignments that the user applies and removes in one step.
///
/// AltTab+ ships without assigned module shortcuts, because the combinations worth having are usually
/// already taken on the target machines. A preset makes a useful set available as a decision instead of
/// as a default, and it removes exactly what it assigned: an entry the user changed afterwards stays
/// untouched.
struct ShortcutPreset {
    let id: String
    /// Presets of one domain assign the same preference keys, so only one of them can be active.
    let domain: String
    let title: String
    let summary: String
    let assignments: [(key: String, shortcut: Shortcut)]

    /// Stored rather than derived from the assignments: a preset stays active when single shortcuts are
    /// changed afterwards, otherwise one edit would silently release the domain for another preset.
    var isActive: Bool {
        ShortcutPresets.activeId(in: domain) == id
    }

    /// Whether the shortcuts still are what this preset assigned. A difference means the user adjusted
    /// something while it was active, which removing the preset would discard.
    var hasCustomChanges: Bool {
        isActive && !assignments.allSatisfy { Preferences.shortcut($0.key) == $0.shortcut }
    }

    private var backupKey: String { "presetBackup.\(id)" }

    /// Overwrites whatever the keys carry. What they carried is kept, so removing the preset restores
    /// the state from before it was assigned instead of just clearing the fields.
    func apply() {
        storeBackup()
        assignments.forEach { Preferences.setShortcut($0.key, $0.shortcut) }
        ShortcutPresets.setActiveId(id, in: domain)
        NativeSystemShortcuts.apply()
    }

    func remove() {
        restoreBackup()
        ShortcutPresets.setActiveId(nil, in: domain)
        NativeSystemShortcuts.apply()
    }

    private func storeBackup() {
        var backup = [String: [String: Int]]()
        assignments.forEach { assignment in
            guard let existing = Preferences.shortcut(assignment.key) else {
                // an empty entry records that the key was unassigned before
                backup[assignment.key] = [:]
                return
            }
            backup[assignment.key] = ["code": Int(existing.keyCode.rawValue), "flags": Int(existing.modifierFlags.rawValue)]
        }
        UserDefaults.standard.set(backup, forKey: backupKey)
    }

    private func restoreBackup() {
        let backup = UserDefaults.standard.dictionary(forKey: backupKey) as? [String: [String: Int]]
        assignments.forEach { assignment in
            guard let entry = backup?[assignment.key] else {
                // no record of the previous state: at least take back what the preset assigned
                if Preferences.shortcut(assignment.key) == assignment.shortcut {
                    Preferences.setShortcut(assignment.key, nil)
                }
                return
            }
            guard let code = entry["code"], let flags = entry["flags"], let keyCode = KeyCode(rawValue: CGKeyCode(code)) else {
                Preferences.setShortcut(assignment.key, nil)
                return
            }
            Preferences.setShortcut(assignment.key, ShortcutPresets.shortcut(keyCode, NSEvent.ModifierFlags(rawValue: UInt(flags))))
        }
        UserDefaults.standard.removeObject(forKey: backupKey)
    }
}

enum ShortcutPresets {
    private static let activeKey = "activeShortcutPresets"
    private static let spacesDomain = "spaces"
    private static let layoutsDomain = "layouts"
    private static let hyper: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

    static func activeId(in domain: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: activeKey) as? [String: String])?[domain]
    }

    static func setActiveId(_ id: String?, in domain: String) {
        var active = (UserDefaults.standard.dictionary(forKey: activeKey) as? [String: String]) ?? [:]
        active[domain] = id
        UserDefaults.standard.set(active, forKey: activeKey)
    }

    /// A preset can only be assigned while its domain is free, so the two sets of one domain cannot
    /// overwrite each other unnoticed.
    static func isAssignable(_ preset: ShortcutPreset) -> Bool {
        activeId(in: preset.domain) == nil
    }
    private static let digitKeyCodes: [KeyCode] = [.ansi0, .ansi1, .ansi2, .ansi3, .ansi4, .ansi5, .ansi6, .ansi7, .ansi8, .ansi9]

    static func shortcut(_ code: KeyCode, _ modifierFlags: NSEvent.ModifierFlags) -> Shortcut {
        Shortcut(code: code, modifierFlags: modifierFlags, characters: nil, charactersIgnoringModifiers: nil)
    }

    private static func spaceAssignments(_ modifierFlags: NSEvent.ModifierFlags) -> [(key: String, shortcut: Shortcut)] {
        SpaceAction.all.compactMap { action in
            switch action {
            case .left: return (action.shortcutPreferenceKey, shortcut(.leftArrow, modifierFlags))
            case .right: return (action.shortcutPreferenceKey, shortcut(.rightArrow, modifierFlags))
            case .last: return (action.shortcutPreferenceKey, shortcut(digitKeyCodes[0], modifierFlags))
            case .index(let index): return (action.shortcutPreferenceKey, shortcut(digitKeyCodes[index], modifierFlags))
            }
        }
    }

    /// The letters follow Rectangle, so muscle memory carries over. AltTab+ has no halves or quarters,
    /// so only the actions with a counterpart there are assigned; the rest stays free on purpose.
    private static func layoutAssignments(_ modifierFlags: NSEvent.ModifierFlags) -> [(key: String, shortcut: Shortcut)] {
        [
            (WindowLayoutAction.leftThird.shortcutPreferenceKey, shortcut(.ansiD, modifierFlags)),
            (WindowLayoutAction.rightThird.shortcutPreferenceKey, shortcut(.ansiG, modifierFlags)),
            (WindowLayoutAction.leftTwoThirds.shortcutPreferenceKey, shortcut(.ansiE, modifierFlags)),
            (WindowLayoutAction.rightTwoThirds.shortcutPreferenceKey, shortcut(.ansiT, modifierFlags)),
            (WindowLayoutAction.restore.shortcutPreferenceKey, shortcut(.delete, modifierFlags)),
        ]
    }

    /// macOS owns `Control` plus a digit and `Control` plus an arrow for Spaces, so applying this hands
    /// those system shortcuts to AltTab+ until the preset is removed.
    static let macOsSpaces = ShortcutPreset(
        id: "macOsSpaces",
        domain: spacesDomain,
        title: NSLocalizedString("macOS Spaces shortcuts", comment: ""),
        summary: NSLocalizedString("Control plus 1 to 9 switches to that Space, Control plus 0 toggles back to the last one, Control plus an arrow moves one Space. The matching system shortcuts, including native window tiling on the same combination, are disabled while this is assigned and restored when it is removed.", comment: ""),
        assignments: spaceAssignments(.control))

    /// Leaves every macOS shortcut alone, at the price of needing the Hyper key enabled.
    static let hyperSpaces = ShortcutPreset(
        id: "hyperSpaces",
        domain: spacesDomain,
        title: NSLocalizedString("Hyper key Spaces shortcuts", comment: ""),
        summary: NSLocalizedString("The same set on the Hyper key instead of Control, so no macOS shortcut has to be disabled. Requires the Hyper key to be enabled.", comment: ""),
        assignments: spaceAssignments(hyper))

    static let rectangleLayouts = ShortcutPreset(
        id: "rectangleLayouts",
        domain: layoutsDomain,
        title: NSLocalizedString("Rectangle-style layout shortcuts", comment: ""),
        summary: NSLocalizedString("Control and Option with D, G, E, T for thirds and two-thirds, and with Delete for restore, matching Rectangle and Magnet. Conflicts if one of those apps is running.", comment: ""),
        assignments: layoutAssignments([.control, .option]))

    static let hyperLayouts = ShortcutPreset(
        id: "hyperLayouts",
        domain: layoutsDomain,
        title: NSLocalizedString("Hyper key layout shortcuts", comment: ""),
        summary: NSLocalizedString("The same letters on the Hyper key, which stays clear of Rectangle and Magnet. Requires the Hyper key to be enabled.", comment: ""),
        assignments: layoutAssignments(hyper))

    static let spaces = [macOsSpaces, hyperSpaces]
    static let layouts = [rectangleLayouts, hyperLayouts]
    static let all = spaces + layouts
}
