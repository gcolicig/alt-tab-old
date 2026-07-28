import Cocoa

class Menubar {
    static var statusItem: NSStatusItem!
    static var menu: NSMenu!
    static var permissionCalloutMenuItems: [NSMenuItem]?
    private static let iconWidth = CGFloat(28)
    private static var customIconView: NSImageView?
    private static var spaceSegmentsView: NSView?

    static func addMenuItem(_ title: String, _ action: Selector, _ keyEquivalent: String, _ symbolName: String?, _ color: NSColor? = nil, _ target: AnyObject? = nil) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        if #available(macOS 26.0, *), let symbolName {
            item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            if let color {
                item.image = item.image?.withSymbolConfiguration(.init(paletteColors: [color]))
            }
        }
    }

    static func initialize() {
        menu = NSMenu()
        menu.title = App.name // perf: prevent going through expensive code-path within appkit
        let permissionCalloutMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        permissionCalloutMenuItem.view = PermissionCallout()
        let calloutSeparator = NSMenuItem.separator()
        permissionCalloutMenuItems = [permissionCalloutMenuItem, calloutSeparator]
        addMenuItem(NSLocalizedString("Show", comment: "Menubar option"), #selector(App.showUiFromShortcut0), "", "eye", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(NSLocalizedString("Settings…", comment: "Menubar option"), #selector(App.showSettingsWindow), ",", "gear", nil, App.self)
        addMenuItem(NSLocalizedString("Check permissions…", comment: "Menubar option"), #selector(App.checkPermissions), "", "hand.raised", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(String(format: NSLocalizedString("About %@", comment: "Menubar option. %@ is AltTab"), App.name), #selector(App.showAboutWindow), "", "info.circle", nil, App.self)
        addMenuItem(NSLocalizedString("Debug tools", comment: "Menubar option"), #selector(App.showDebugWindow), "", "scope", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(String(format: NSLocalizedString("Quit %@", comment: "Menubar option. %@ is AltTab"), App.name), #selector(NSApplication.terminate(_:)), "q", nil) // "xmark.rectangle" is not necessary; macos automatically recognizes Quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.target = self
        statusItem.button!.action = #selector(statusItemOnClick)
        statusItem.button!.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    // NSMenuItem.isHidden isn't reliable with custom views. We add/remove to hide/show these items
    static func togglePermissionCallout(_ show: Bool) {
        permissionCalloutMenuItems?.enumerated().forEach { offset, element in
            if show && !menu.items.contains(element) {
                menu.insertItem(element, at: offset)
            }
            if !show && menu.items.contains(element) {
                menu.removeItem(element)
            }
        }
    }

    @objc static func statusItemOnClick() {
        refreshSpaces()
        // NSApp.currentEvent == nil if the icon is "clicked" through VoiceOver
        if let type = NSApp.currentEvent?.type, type != .leftMouseDown {
            App.showUiFromShortcut0()
        } else {
            statusItem.popUpMenu(Menubar.menu)
        }
    }

    static func menubarIconCallback(_: NSControl?) {
        if Preferences.menubarIconShown {
            loadPreferredIcon()
        } else {
            statusItem.isVisible = false
        }
        refreshSpaces()
        if let menubarIconDropdown = GeneralTab.menubarIconDropdown {
            menubarIconDropdown.isEnabled = Preferences.menubarIconShown
        }
    }

    static private func loadPreferredIcon() {
        statusItem.button!.image = preferredIcon()
        statusItem.isVisible = true
        statusItem.button!.imageScaling = .scaleProportionallyUpOrDown
    }

    static func refreshSpaces() {
        // a multi-step switch passes through every Space in between; rendering those would walk the
        // highlight across the row. InstantSpaces refreshes once more when the sequence settles.
        guard !InstantSpaces.isSwitching else { return }
        guard statusItem != nil, let statusButton = statusItem.button else { return }
        if Preferences.menubarIconShown, Preferences.spacesInMenubarShown {
            Spaces.refresh()
            // rebuilding the row on every Space change tore down the buttons while the mouse was still
            // on them, which swallowed clicks. Restyle in place whenever the segments still fit.
            if let model = spaceModel(), restyleExistingSegments(model) { return }
        }
        customIconView?.removeFromSuperview()
        spaceSegmentsView?.removeFromSuperview()
        customIconView = nil
        spaceSegmentsView = nil
        statusButton.image = preferredIcon()
        statusItem.length = NSStatusItem.squareLength
        statusButton.alignment = .center
        guard Preferences.menubarIconShown, Preferences.spacesInMenubarShown else { return }
        Spaces.refresh()
        guard let model = spaceModel(), !model.spaceIds.isEmpty else { return }
        let segmentWidth = CGFloat(28)
        let segmentsWidth = segmentWidth * CGFloat(model.spaceIds.count)
        let container = NSView(frame: NSRect(x: iconWidth, y: 0, width: segmentsWidth, height: statusButton.bounds.height))
        let switchingEnabled = InstantSpaces.runtimeAvailability().isAvailable
        model.spaceIds.enumerated().forEach { offset, spaceId in
            let button = spaceButton(offset + 1, spaceId == model.activeSpaceId, switchingEnabled)
            button.frame = NSRect(x: CGFloat(offset) * segmentWidth + 2, y: 3, width: segmentWidth - 4, height: max(18, container.bounds.height - 6))
            container.addSubview(button)
        }
        statusItem.length = iconWidth + segmentsWidth + 2
        statusButton.image = nil
        let iconView = PassthroughImageView(frame: NSRect(x: 4, y: 2, width: 20, height: max(18, statusButton.bounds.height - 4)))
        iconView.image = preferredIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        statusButton.addSubview(iconView)
        statusButton.addSubview(container)
        customIconView = iconView
        spaceSegmentsView = container
    }

    /// Updates the existing segments instead of recreating them. Returns false when the row has to be
    /// rebuilt, for example after the number of Spaces changed.
    private static func restyleExistingSegments(_ model: (spaceIds: [CGSSpaceID], activeSpaceId: CGSSpaceID?)) -> Bool {
        guard let container = spaceSegmentsView, !model.spaceIds.isEmpty else { return false }
        let buttons = container.subviews.compactMap { $0 as? NSButton }
        guard buttons.count == model.spaceIds.count else { return false }
        let switchingEnabled = InstantSpaces.runtimeAvailability().isAvailable
        zip(buttons, model.spaceIds).enumerated().forEach { offset, pair in
            styleSpaceButton(pair.0, offset + 1, pair.1 == model.activeSpaceId, switchingEnabled)
        }
        return true
    }

    private static func preferredIcon() -> NSImage {
        let index = Preferences.menubarIcon.indexAsString
        let image = NSImage(named: "menubar-\(index)")!
        image.isTemplate = index != "2"
        return image
    }

    private static func spaceModel() -> (spaceIds: [CGSSpaceID], activeSpaceId: CGSSpaceID?)? {
        guard let cursorUuid = NSScreen.withMouse()?.cachedUuid() else { return nil }
        let spaceIds = Spaces.screenSpacesMap[cursorUuid] ?? Spaces.screenSpacesMap.first?.value
        guard let spaceIds else { return nil }
        return (Array(spaceIds.prefix(9)), spaceIds.first { Spaces.visibleSpaces.contains($0) })
    }

    private static func spaceButton(_ index: Int, _ active: Bool, _ enabled: Bool) -> NSButton {
        let button = NSButton(title: "\(index)", target: self, action: #selector(spaceSegmentOnClick(_:)))
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        styleSpaceButton(button, index, active, enabled)
        return button
    }

    private static func styleSpaceButton(_ button: NSButton, _ index: Int, _ active: Bool, _ enabled: Bool) {
        button.tag = index
        button.isEnabled = enabled
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: active ? .semibold : .medium)
        button.toolTip = String(format: NSLocalizedString("Switch to Space %d", comment: ""), index)
        button.setAccessibilityLabel(button.toolTip)
        let color: NSColor
        if #available(macOS 10.14, *) {
            color = NSApp.effectiveAppearance.getThemeName() == .dark ? .white : .black
        } else {
            color = .black
        }
        button.attributedTitle = NSAttributedString(string: "\(index)", attributes: [.font: font, .foregroundColor: color])
        button.layer?.backgroundColor = active ? color.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = color.withAlphaComponent(active ? 0.9 : 0.28).cgColor
        button.layer?.borderWidth = 1
    }

    @objc private static func spaceSegmentOnClick(_ sender: NSButton) {
        let appWasActive = NSApp.isActive
        Actions.perform(.space(.index(sender.tag)))
        // clicking a status item activates AltTab+, and macOS then pulls the screen to the Space that
        // holds an AltTab+ window, which undid the switch that was just performed
        if !appWasActive {
            NSApp.deactivate()
        }
    }
}

private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

class PermissionCallout: StackView {
    convenience init() {
        let label = NSTextField(wrappingLabelWithString: NSLocalizedString("AltTab is running without Screen Recording permissions. Thumbnails won’t show.", comment: "Menubar callout"))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.preferredMaxLayoutWidth = 250
        label.isSelectable = false
        label.addOrUpdateConstraint(label.widthAnchor, 250)
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.attributedTitle = NSAttributedString(string: NSLocalizedString("Grant permission", comment: "Menubar callout button"), attributes: [NSAttributedString.Key.foregroundColor: NSColor.white])
        button.onAction = { _ in
            Preferences.remove("screenRecordingPermissionSkipped")
            App.restart()
        }
        self.init([label, button], .vertical, true, top: 8, right: 15, bottom: 10, left: 15)
        wantsLayer = true
        layer!.backgroundColor = NSColor.purple.cgColor
    }
}
