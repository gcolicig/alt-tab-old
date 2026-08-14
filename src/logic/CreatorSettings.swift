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
        // input modules this set is allowed to arm; see the Q-08 carve-out below.
        // The modifier indexes point into `DragModifierPreference.selectable`: 1 = Command+Control, 2 = Command+Option.
        ("hyperKeyEnabled", "true"),
        ("windowDragModifier", "1"),
        ("windowResizeModifier", "2"),
    ]

    private static let presets = [ShortcutPresets.hyperSpaces, ShortcutPresets.hyperLayouts]

    /// Q-08: an applied set never arms an input module. The named exceptions, decided on 2026-08-14, are
    /// `hyperKeyEnabled` (what makes the two shortcut presets usable at all) and the two drag modifiers
    /// (`Command+Control` move, `Command+Option` resize): applying the set is itself a deliberate act behind
    /// a summary the user confirms. The rule was amended rather than sidestepped — Q-08 carries the
    /// carve-out — and the summary names each armed module in its own sentence, because "assigns the Hyper
    /// presets" reads as key bindings, not as taking over a key or consuming mouse clicks.
    ///
    /// `Command+Control` additionally needs the global drag-on-gesture switch off; the launch path acquires
    /// and verifies that ownership like any deliberate activation, and refuses the modifier if it cannot.
    private static let excludedInputModuleKeys: Set<String> = ["nextWindowGesture"]

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
         NSLocalizedString("Assigns the Hyper presets for Spaces and Window Layouts.", comment: ""),
         // each armed input module is named in its own sentence, as the Q-08 carve-out requires
         NSLocalizedString("Turns on Hyperkey, which remaps Caps Lock system-wide. You can turn it off again under Hyperkey.", comment: ""),
         NSLocalizedString("Turns on moving windows with Command-Control and resizing with Command-Option held. Command-Control also turns off the macOS drag-on-gesture setting while assigned. Both can be turned off again under Window Layouts.", comment: "")]
            .joined(separator: "\n")
    }
}
