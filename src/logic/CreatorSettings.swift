import Cocoa

/// The configuration the fork's author runs, offered as a one-click starting point for anyone who does not
/// want to assemble one from scratch.
///
/// Only settings that express a preference are included. Window positions, the status item slot, update
/// state and migration markers describe one machine rather than a way of working, and copying them onto
/// somebody else's setup would be noise at best.
enum CreatorSettings {
    /// Plain preference values. Shortcuts are not listed here: the author's assignments are exactly the two
    /// Hyper presets the app already ships, so they are applied through the preset machinery, which also
    /// records what it replaced and can hand it back.
    private static let values: [(key: String, value: String)] = [
        ("appearanceStyle", AppearanceStylePreference.titles.indexAsString),
        ("showTabsAsWindows", "true"),
        ("spacesInMenubarShown", "true"),
        ("hideAppBadges", "true"),
        ("hideStatusIcons", "true"),
        ("windowDisplayDelay", "0"),
        ("previewFadeInAnimation", "false"),
    ]

    private static let presets = [ShortcutPresets.hyperSpaces, ShortcutPresets.hyperLayouts]

    /// Q-08: an applied set never arms an input module. The author runs the modifier move on `Command+Shift`,
    /// but a preset that switches on a tap consuming mouse clicks — without the user having decided to — is
    /// exactly what that rule exists to prevent. It stays out, and the dialog says so.
    private static let excludedInputModuleKeys: Set<String> = ["windowDragModifier", "hyperKeyEnabled", "nextWindowGesture"]

    /// Enforced rather than merely intended: a later edit that adds an input-module key to `values` is
    /// dropped here instead of quietly arming a tap on somebody else's machine.
    static func apply() {
        values.filter { !excludedInputModuleKeys.contains($0.key) }
            .forEach { Preferences.set($0.key, $0.value) }
        presets.forEach { $0.apply() }
    }

    static var summary: String {
        [NSLocalizedString("Shows window titles instead of thumbnails, and tabs as separate windows.", comment: ""),
         NSLocalizedString("Hides app badges and status icons.", comment: ""),
         NSLocalizedString("Opens the switcher without delay and without the preview fade.", comment: ""),
         NSLocalizedString("Shows Spaces next to the menu bar icon.", comment: ""),
         NSLocalizedString("Assigns the Hyper presets for Spaces and Window Layouts.", comment: "")]
            .joined(separator: "\n")
    }
}
