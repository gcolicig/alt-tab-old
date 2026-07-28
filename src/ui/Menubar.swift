import Cocoa

class Menubar {
    static var statusItem: NSStatusItem!
    static var menu: NSMenu!
    static var permissionCalloutMenuItems: [NSMenuItem]?
    private static let iconWidth = CGFloat(28)
    private static let segmentWidth = CGFloat(28)
    private static let groupGap = CGFloat(6)
    /// Segments beyond this count per display collapse into an overflow button.
    private static let maxDirectSegmentsPerGroup = 9
    private static var customIconView: NSImageView?
    private static var spaceSegmentsView: NSView?

    private struct SpaceGroup {
        let displayUuid: ScreenUuid
        let spaceIds: [CGSSpaceID]
        let activeSpaceId: CGSSpaceID?
    }

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

    /// `spacesAreFresh` skips the `Spaces.refresh` when the caller just did it, which keeps the Space
    /// change path down to a single query of the Space list.
    static func refreshSpaces(spacesAreFresh: Bool = false) {
        // a multi-step switch passes through every Space in between; rendering those would walk the
        // highlight across the row. InstantSpaces refreshes once more when the sequence settles.
        guard !InstantSpaces.isSwitching else { return }
        guard statusItem != nil, let statusButton = statusItem.button else { return }
        if Preferences.menubarIconShown, Preferences.spacesInMenubarShown {
            if !spacesAreFresh {
                Spaces.refresh()
            }
            let groups = spaceGroups()
            // rebuilding the row on every Space change tore down the buttons while the mouse was still
            // on them, which swallowed clicks. Restyle in place whenever the layout still fits; only a
            // single-display row is restyled today, multi-group and overflow layouts always rebuild.
            if groups.count == 1, restyleExistingSegments(groups[0]) { return }
        }
        customIconView?.removeFromSuperview()
        spaceSegmentsView?.removeFromSuperview()
        customIconView = nil
        spaceSegmentsView = nil
        statusButton.image = preferredIcon()
        statusItem.length = NSStatusItem.squareLength
        statusButton.alignment = .center
        guard Preferences.menubarIconShown, Preferences.spacesInMenubarShown else { return }
        let groups = spaceGroups()
        guard !groups.isEmpty else { return }
        let switchingEnabled = InstantSpaces.runtimeAvailability().isAvailable
        let cursorUuid = NSScreen.withMouse()?.cachedUuid()
        let container = NSView(frame: .zero)
        var x = CGFloat(0)
        groups.enumerated().forEach { groupOffset, group in
            if groupOffset > 0 {
                x += groupGap
                container.addSubview(groupDivider(x: x, height: statusButton.bounds.height))
                x += groupGap
            }
            x += addGroupSegments(group, startX: x, height: statusButton.bounds.height, switchingEnabled: switchingEnabled,
                                   isCursorGroup: cursorUuid == nil || cursorUuid == group.displayUuid,
                                   displayOrdinal: groups.count > 1 ? groupOffset + 1 : nil, into: container)
        }
        container.frame = NSRect(x: iconWidth, y: 0, width: x, height: statusButton.bounds.height)
        statusItem.length = iconWidth + x + 2
        statusButton.image = nil
        let iconView = PassthroughImageView(frame: NSRect(x: 4, y: 2, width: 20, height: max(18, statusButton.bounds.height - 4)))
        iconView.image = preferredIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        statusButton.addSubview(iconView)
        statusButton.addSubview(container)
        customIconView = iconView
        spaceSegmentsView = container
    }

    /// Adds the segments for one display group and returns the width consumed. `displayOrdinal` is only
    /// set when more than one group is shown, so VoiceOver can name which display a segment belongs to.
    private static func addGroupSegments(_ group: SpaceGroup, startX: CGFloat, height: CGFloat, switchingEnabled: Bool,
                                          isCursorGroup: Bool, displayOrdinal: Int?, into container: NSView) -> CGFloat {
        let directCount = group.spaceIds.count > maxDirectSegmentsPerGroup ? maxDirectSegmentsPerGroup - 1 : group.spaceIds.count
        let hasOverflow = group.spaceIds.count > directCount
        (0..<directCount).forEach { offset in
            let button = spaceButton(offset + 1, group.spaceIds[offset] == group.activeSpaceId, switchingEnabled && isCursorGroup, !isCursorGroup, displayOrdinal, group.displayUuid)
            button.frame = NSRect(x: startX + CGFloat(offset) * segmentWidth + 2, y: 3, width: segmentWidth - 4, height: max(18, height - 6))
            container.addSubview(button)
        }
        guard hasOverflow else { return CGFloat(directCount) * segmentWidth }
        let overflowIndexes = Array((directCount + 1)...group.spaceIds.count)
        let overflowButton = overflowButton(overflowIndexes, group.spaceIds, group.activeSpaceId, switchingEnabled && isCursorGroup, !isCursorGroup, displayOrdinal, group.displayUuid)
        overflowButton.frame = NSRect(x: startX + CGFloat(directCount) * segmentWidth + 2, y: 3, width: segmentWidth - 4, height: max(18, height - 6))
        container.addSubview(overflowButton)
        return CGFloat(directCount + 1) * segmentWidth
    }

    private static func groupDivider(x: CGFloat, height: CGFloat) -> NSView {
        let divider = NSBox(frame: NSRect(x: x, y: 4, width: 1, height: max(10, height - 8)))
        divider.boxType = .separator
        // decorative only: VoiceOver should skip straight from one display's segments to the next
        divider.setAccessibilityElement(false)
        return divider
    }

    /// Updates the existing single-group segments in place. Returns false when the row has to be rebuilt.
    private static func restyleExistingSegments(_ group: SpaceGroup) -> Bool {
        guard let container = spaceSegmentsView, !group.spaceIds.isEmpty, group.spaceIds.count <= maxDirectSegmentsPerGroup else { return false }
        let buttons = container.subviews.compactMap { $0 as? NSButton }
        guard buttons.count == group.spaceIds.count else { return false }
        let switchingEnabled = InstantSpaces.runtimeAvailability().isAvailable
        zip(buttons, group.spaceIds).enumerated().forEach { offset, pair in
            styleSpaceButton(pair.0, offset + 1, pair.1 == group.activeSpaceId, switchingEnabled, false)
        }
        return true
    }

    private static func preferredIcon() -> NSImage {
        let index = Preferences.menubarIcon.indexAsString
        let image = NSImage(named: "menubar-\(index)")!
        image.isTemplate = index != "2"
        return image
    }

    /// Displays are ordered left to right, then top to bottom. Groups with separate Spaces collapse to a
    /// single shared group when the system setting `Displays have separate Spaces` is off, since macOS
    /// then reports one shared display identifier for all screens.
    private static func spaceGroups() -> [SpaceGroup] {
        guard !Spaces.screenSpacesMap.isEmpty else { return [] }
        let orderedScreenUuids = NSScreen.screens
            .sorted { $0.frame.origin.x != $1.frame.origin.x ? $0.frame.origin.x < $1.frame.origin.x : $0.frame.origin.y < $1.frame.origin.y }
            .compactMap { $0.cachedUuid() }
        var seen = Set<ScreenUuid>()
        var orderedUuids = orderedScreenUuids.filter { Spaces.screenSpacesMap[$0] != nil && seen.insert($0).inserted }
        Spaces.screenSpacesMap.keys.forEach { uuid in
            if !seen.contains(uuid) {
                orderedUuids.append(uuid)
                seen.insert(uuid)
            }
        }
        return orderedUuids.compactMap { uuid in
            guard let spaceIds = Spaces.screenSpacesMap[uuid], !spaceIds.isEmpty else { return nil }
            return SpaceGroup(displayUuid: uuid, spaceIds: spaceIds, activeSpaceId: spaceIds.first { Spaces.visibleSpaces.contains($0) })
        }
    }

    private static func spaceButton(_ index: Int, _ active: Bool, _ enabled: Bool, _ crossDisplay: Bool, _ displayOrdinal: Int?, _ displayUuid: ScreenUuid) -> NSButton {
        let button = NSButton(title: "\(index)", target: self, action: #selector(spaceSegmentOnClick(_:)))
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.identifier = NSUserInterfaceItemIdentifier(displayUuid as String)
        styleSpaceButton(button, index, active, enabled, crossDisplay, displayOrdinal)
        return button
    }

    private static func overflowButton(_ indexes: [Int], _ spaceIds: [CGSSpaceID], _ activeSpaceId: CGSSpaceID?, _ enabled: Bool, _ crossDisplay: Bool, _ displayOrdinal: Int?, _ displayUuid: ScreenUuid) -> NSButton {
        let button = NSButton(title: "…", target: self, action: #selector(spaceOverflowOnClick(_:)))
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.identifier = NSUserInterfaceItemIdentifier(displayUuid as String)
        button.isEnabled = enabled
        button.alphaValue = crossDisplay ? 0.4 : 1
        let baseTooltip = crossDisplay ? crossDisplayTooltip() : NSLocalizedString("More Spaces", comment: "")
        button.toolTip = displayOrdinal.map { String(format: NSLocalizedString("%@ (Display %d)", comment: ""), baseTooltip, $0) } ?? baseTooltip
        button.setAccessibilityLabel(button.toolTip)
        let activeInOverflow = indexes.contains { spaceIds[$0 - 1] == activeSpaceId }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: activeInOverflow ? .semibold : .medium)
        let color: NSColor = if #available(macOS 10.14, *) { NSApp.effectiveAppearance.getThemeName() == .dark ? .white : .black } else { .black }
        button.attributedTitle = NSAttributedString(string: "…", attributes: [.font: font, .foregroundColor: color])
        button.layer?.backgroundColor = activeInOverflow ? color.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = color.withAlphaComponent(activeInOverflow ? 0.9 : 0.28).cgColor
        button.layer?.borderWidth = 1
        overflowIndexesByButton[ObjectIdentifier(button)] = indexes
        return button
    }

    private static func styleSpaceButton(_ button: NSButton, _ index: Int, _ active: Bool, _ enabled: Bool, _ crossDisplay: Bool, _ displayOrdinal: Int? = nil) {
        button.tag = index
        button.isEnabled = enabled
        button.alphaValue = crossDisplay ? 0.4 : 1
        let baseTooltip = crossDisplay ? crossDisplayTooltip() : String(format: NSLocalizedString("Switch to Space %d", comment: ""), index)
        button.toolTip = displayOrdinal.map { String(format: NSLocalizedString("%@ (Display %d)", comment: ""), baseTooltip, $0) } ?? baseTooltip
        button.setAccessibilityLabel(button.toolTip)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: active ? .semibold : .medium)
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

    /// Segments are only wired to the shared action register up to Space 9; overflow indexes beyond
    /// that reach the same underlying switch directly, since only a shortcut needs a registered action.
    private static var overflowIndexesByButton = [ObjectIdentifier: [Int]]()

    @objc private static func spaceSegmentOnClick(_ sender: NSButton) {
        guard cursorMatchesGroup(sender) else { return }
        if sender.tag <= 9 {
            Actions.perform(.space(.index(sender.tag)))
        } else {
            InstantSpaces.perform(.index(sender.tag))
        }
    }

    @objc private static func spaceOverflowOnClick(_ sender: NSButton) {
        guard cursorMatchesGroup(sender), let indexes = overflowIndexesByButton[ObjectIdentifier(sender)] else { return }
        let menu = NSMenu()
        indexes.forEach { index in
            let item = menu.addItem(withTitle: String(format: NSLocalizedString("Space %d", comment: ""), index), action: #selector(spaceOverflowItemOnClick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private static func spaceOverflowItemOnClick(_ sender: NSMenuItem) {
        InstantSpaces.perform(.index(sender.tag))
    }

    /// A single, unmirrored menu bar renders every display's group on whichever screen shows it; a click
    /// there always has the cursor on that screen, not necessarily the group's own display. Instant
    /// Spaces can only switch the display the cursor is physically on (it posts synthetic trackpad
    /// gestures, which carry no target-display field), so a mismatched click is silently ignored rather
    /// than switching the wrong display's Spaces.
    private static func cursorMatchesGroup(_ button: NSButton) -> Bool {
        guard let groupUuid = button.identifier?.rawValue, let cursorUuid = NSScreen.withMouse()?.cachedUuid() else { return true }
        return groupUuid == cursorUuid as String
    }

    private static func crossDisplayTooltip() -> String {
        NSLocalizedString("Move the cursor to this screen to switch its Spaces.", comment: "")
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
