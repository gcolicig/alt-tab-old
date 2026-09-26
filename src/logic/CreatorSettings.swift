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
        ("showTitles", ShowTitlesPreference.appNameAndWindowTitle.indexAsString),
        ("hideSpaceNumberLabels", "true"),
        ("catModeMinutes", "30"),
        // every app except Finder, menu bar apps and apps with their own menu bar item; see AutoQuitPolicy
        ("autoQuitEnabled", "true"),
        ("autoQuitDelaySeconds", "60"),
        ("autoQuitMode", String(AutoQuitMode.allExceptListed.rawValue)),
        ("keepAwakeDisplay", "true"),
        ("keepAwakeBatteryThreshold", "10"),
        // FlickRing on the middle mouse button (button number 2), one focus layout per direction
        ("flickRingButton", "2"),
        ("flickRingUp", "windowLayout.centerFocus"),
        ("flickRingDown", "windowLayout.restore"),
        ("flickRingLeft", "windowLayout.leftFocus"),
        ("flickRingRight", "windowLayout.rightFocus"),
        // input modules this set is allowed to arm; see the Q-08 carve-out below.
        // The modifier indexes point into `DragModifierPreference.selectable`: 1 = Command+Control, 2 = Command+Option.
        ("hyperKeyEnabled", "true"),
        ("windowDragModifier", "1"),
        ("windowResizeModifier", "2"),
        ("flickRingEnabled", "true"),
    ]

    private static let presets = [ShortcutPresets.hyperSpaces, ShortcutPresets.hyperLayouts]

    /// Q-08: an applied set never arms an input module. The named exceptions, decided on 2026-08-14, are
    /// `hyperKeyEnabled` (what makes the two shortcut presets usable at all) and the two drag modifiers
    /// (`Command+Control` move, `Command+Option` resize); `flickRingEnabled` was added on 2026-09-17. Leader
    /// is not an exception and stays off: applying the set is itself a deliberate act behind
    /// a summary the user confirms. The rule was amended rather than sidestepped — Q-08 carries the
    /// carve-out — and the summary names each armed module in its own sentence, because "assigns the Hyper
    /// presets" reads as key bindings, not as taking over a key or consuming mouse clicks.
    ///
    /// `Command+Control` additionally needs the global drag-on-gesture switch off; the launch path acquires
    /// and verifies that ownership like any deliberate activation, and refuses the modifier if it cannot.
    private static let excludedInputModuleKeys: Set<String> = ["nextWindowGesture", "leaderEnabled", "typingMuteEnabled"]

    /// Enforced rather than merely intended: a later edit that adds an input-module key to `values` is
    /// dropped here instead of quietly arming a tap on somebody else's machine.
    static func apply() {
        values.filter { !excludedInputModuleKeys.contains($0.key) }
            .forEach { Preferences.set($0.key, $0.value) }
        presets.forEach { $0.apply() }
    }

    /// One line per change, each with the symbol the menu uses for the same area, so the confirmation reads
    /// as a list rather than a paragraph.
    static var summaryItems: [(symbol: String, text: String)] {
        [("list.bullet.rectangle", NSLocalizedString("Shows window titles with the app name instead of thumbnails, and tabs as separate windows.", comment: "")),
         ("app.badge", NSLocalizedString("Hides app badges and status icons.", comment: "")),
         ("bolt", NSLocalizedString("Opens the switcher without delay and without the preview fade.", comment: "")),
         ("menubar.rectangle", NSLocalizedString("Shows Spaces next to the menu bar icon, without Space numbers in the switcher.", comment: "")),
         ("power", NSLocalizedString("Turns on Auto-Quit: an app quits 60 seconds after its last window closed, unless it is frontmost again. Finder, menu bar apps and apps with their own menu bar item keep running.", comment: "")),
         ("cup.and.saucer", NSLocalizedString("Ends Cat Mode after 30 minutes. Keep Awake also keeps the display on, and ends on battery at 10%.", comment: "")),
         ("keyboard", NSLocalizedString("Assigns the Hyper presets for Spaces and Window Layouts: A, W and D for left, center and right focus, S for restore.", comment: "")),
         // each armed input module is named in its own line, as the Q-08 carve-out requires
         ("capslock", NSLocalizedString("Turns on Hyperkey, which remaps Caps Lock system-wide. You can turn it off again under Hyperkey.", comment: "")),
         ("computermouse", NSLocalizedString("Turns on FlickRing, which takes over the middle mouse button system-wide: a middle click no longer reaches apps. Drag up, down, left or right for center focus, restore, left focus or right focus. You can turn it off again under FlickRing.", comment: "")),
         ("arrow.up.and.down.and.arrow.left.and.right", NSLocalizedString("Turns on moving windows with Command-Control and resizing with Command-Option held. Command-Control also turns off the macOS drag-on-gesture setting while assigned. Both can be turned off again under Window Layouts.", comment: ""))]
    }

    /// The confirmation's list: symbol on the left, text wrapping on the right.
    static func summaryView(width: CGFloat) -> NSView {
        let rows = summaryItems.map { item -> NSView in
            let icon = NSImageView(image: NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) ?? NSImage())
            icon.contentTintColor = .secondaryLabelColor
            // symbols differ in width; pinning each to the left keeps the column edge straight
            icon.imageAlignment = .alignLeft
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
            let text = NSTextField(wrappingLabelWithString: item.text)
            text.preferredMaxLayoutWidth = width - 30
            let row = NSStackView(views: [icon, text])
            row.orientation = .horizontal
            // icon and first line share the top edge, both flush left
            row.alignment = .top
            row.spacing = 10
            return row
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        // the alert places its accessory view slightly left of the informative text; this lines the icons up with it
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        stack.frame = NSRect(origin: .zero, size: NSSize(width: width, height: stack.fittingSize.height))
        return stack
    }
}
