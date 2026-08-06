import Cocoa

class Menubar {
    static var statusItem: NSStatusItem!
    static var menu: NSMenu!
    static var permissionCalloutMenuItems: [NSMenuItem]?
    private static let iconWidth = CGFloat(28)
    private static let segmentWidth = MenubarSpaceRow.segmentWidth
    private static let groupGap = MenubarSpaceRow.groupGap
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
        // the row must never collapse: the status button can still be unsized the first time this runs,
        // and since the icon moves into a subview here, a zero height renders as an empty menubar slot.
        // Beyond that the button's own height wins: `thickness` reports 22 on a menubar that is 32pt tall,
        // and taking the larger of the two placed the row above the button's centre.
        let rowHeight = statusButton.bounds.height > 0 ? statusButton.bounds.height : NSStatusBar.system.thickness
        let totalWidth = MenubarSpaceRow.totalWidth(groups.map { $0.spaceIds.count })
        // the container carries its final frame before any segment goes in, like the single-row version did
        let container = NSView(frame: NSRect(x: iconWidth, y: 0, width: totalWidth, height: rowHeight))
        var x = CGFloat(0)
        groups.enumerated().forEach { groupOffset, group in
            if groupOffset > 0 {
                x += groupGap
                container.addSubview(groupDivider(x: x, height: rowHeight))
                x += groupGap
            }
            x += addGroupSegments(group, startX: x, height: rowHeight, switchingEnabled: switchingEnabled,
                                   isLeadingGroup: groupOffset == 0,
                                   displayOrdinal: groups.count > 1 ? groupOffset + 1 : nil, into: container)
        }
        statusItem.length = iconWidth + totalWidth + 2
        statusButton.image = nil
        let iconView = PassthroughImageView(frame: MenubarSpaceRow.centeredRect(x: 4, width: 20, availableHeight: rowHeight, preferredHeight: MenubarSpaceRow.iconHeight))
        iconView.image = preferredIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        statusButton.addSubview(iconView)
        statusButton.addSubview(container)
        customIconView = iconView
        spaceSegmentsView = container
    }

    /// Adds the segments for one display group and returns the width consumed. `displayOrdinal` is only
    /// set when more than one group is shown, so VoiceOver can name which display a segment belongs to.
    ///
    /// `isLeadingGroup` marks the group of the display the row leads with, which is the one carrying the
    /// menubar. It only shades the frame a little, so the eye can tell the groups apart beyond the
    /// divider. It is deliberately static: it used to track the cursor, which meant the row was only
    /// truthful while the mouse was over it — and reading the row without touching it is its whole point.
    private static func addGroupSegments(_ group: SpaceGroup, startX: CGFloat, height: CGFloat, switchingEnabled: Bool,
                                          isLeadingGroup: Bool, displayOrdinal: Int?, into container: NSView) -> CGFloat {
        let directCount = MenubarSpaceRow.directSegmentCount(group.spaceIds.count)
        let hasOverflow = MenubarSpaceRow.hasOverflow(group.spaceIds.count)
        (0..<directCount).forEach { offset in
            let button = spaceButton(offset + 1, group.spaceIds[offset] == group.activeSpaceId, switchingEnabled, !isLeadingGroup, displayOrdinal, group.displayUuid)
            button.frame = MenubarSpaceRow.centeredRect(x: startX + CGFloat(offset) * segmentWidth + 2, width: segmentWidth - 4, availableHeight: height, preferredHeight: MenubarSpaceRow.segmentHeight)
            container.addSubview(button)
        }
        guard hasOverflow else { return CGFloat(directCount) * segmentWidth }
        let overflowIndexes = MenubarSpaceRow.overflowIndexes(group.spaceIds.count)
        let overflowButton = overflowButton(overflowIndexes, group.spaceIds, group.activeSpaceId, switchingEnabled, !isLeadingGroup, displayOrdinal, group.displayUuid)
        overflowButton.frame = MenubarSpaceRow.centeredRect(x: startX + CGFloat(directCount) * segmentWidth + 2, width: segmentWidth - 4, availableHeight: height, preferredHeight: MenubarSpaceRow.segmentHeight)
        container.addSubview(overflowButton)
        return CGFloat(directCount + 1) * segmentWidth
    }

    private static func groupDivider(x: CGFloat, height: CGFloat) -> NSView {
        let divider = NSBox(frame: MenubarSpaceRow.centeredRect(x: x, width: 1, availableHeight: height, preferredHeight: MenubarSpaceRow.dividerHeight))
        divider.boxType = .separator
        // decorative only: VoiceOver should skip straight from one display's segments to the next
        divider.setAccessibilityElement(false)
        return divider
    }

    /// Updates the existing single-group segments in place. Returns false when the row has to be rebuilt.
    private static func restyleExistingSegments(_ group: SpaceGroup) -> Bool {
        guard let container = spaceSegmentsView, !group.spaceIds.isEmpty, !MenubarSpaceRow.hasOverflow(group.spaceIds.count) else { return false }
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
        // The screen carrying the menubar leads, the rest follow by physical position. Sorting purely by
        // `origin.x` put a display stacked *above* the main one first, because a wider screen centred over
        // a narrower one starts further left: measured -900 against 0. Anchoring on the main screen is
        // stable under every arrangement, where a purely physical order flips as soon as a display moves.
        let orderedScreenUuids = NSScreen.screens
            .sorted { lhs, rhs in
                if isMainScreen(lhs) != isMainScreen(rhs) { return isMainScreen(lhs) }
                if lhs.frame.origin.x != rhs.frame.origin.x { return lhs.frame.origin.x < rhs.frame.origin.x }
                return lhs.frame.origin.y < rhs.frame.origin.y
            }
            .compactMap { $0.cachedUuid() as String? }
        let ordered = MenubarSpaceRow.orderedDisplays(screensInOrder: orderedScreenUuids,
                                                      displaysWithSpaces: Spaces.screenSpacesMap.keys.map { $0 as String })
        let groups = ordered.compactMap { uuid -> SpaceGroup? in
            let key = uuid as ScreenUuid
            guard let spaceIds = Spaces.screenSpacesMap[key], !spaceIds.isEmpty else { return nil }
            return SpaceGroup(displayUuid: key, spaceIds: spaceIds, activeSpaceId: spaceIds.first { Spaces.visibleSpaces.contains($0) })
        }
        let visible = MenubarSpaceRow.visibleGroupIndexes(spaceCounts: groups.map { $0.spaceIds.count },
                                                          separateSpaces: NSScreen.screensHaveSeparateSpaces)
        return visible.map { groups[$0] }
    }

    private static func segmentColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSApp.effectiveAppearance.getThemeName() == .dark ? .white : .black
        }
        return .black
    }

    /// The row states three things, and each gets its own channel so none can be mistaken for another:
    /// how many Spaces a display has, which one is active, and whether a click here can reach it.
    ///
    /// Count is the number of segments. Active is the filled background plus the bolder digit. The frame
    /// carries reachability **alone** — letting it also encode active made "active but unreachable" look
    /// stronger than "inactive but reachable", which says the opposite of what it should. Dimming the
    /// whole segment, as before, made the other display's count and active Space hard to read at all.
    private static func borderAlpha(isLeadingGroup: Bool) -> CGFloat {
        isLeadingGroup ? 0.55 : 0.34
    }

    /// Carries the active Space on its own now that the frame no longer does, so it has to be legible
    /// rather than a hint.
    private static let activeSegmentFill = CGFloat(0.22)

    private static func spaceButton(_ index: Int, _ active: Bool, _ enabled: Bool, _ secondaryGroup: Bool, _ displayOrdinal: Int?, _ displayUuid: ScreenUuid) -> NSButton {
        let button = NSButton(title: "\(index)", target: self, action: #selector(spaceSegmentOnClick(_:)))
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.identifier = NSUserInterfaceItemIdentifier(displayUuid as String)
        styleSpaceButton(button, index, active, enabled, secondaryGroup, displayOrdinal)
        return button
    }

    private static func overflowButton(_ indexes: [Int], _ spaceIds: [CGSSpaceID], _ activeSpaceId: CGSSpaceID?, _ enabled: Bool, _ secondaryGroup: Bool, _ displayOrdinal: Int?, _ displayUuid: ScreenUuid) -> NSButton {
        let button = NSButton(title: "…", target: self, action: #selector(spaceOverflowOnClick(_:)))
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.identifier = NSUserInterfaceItemIdentifier(displayUuid as String)
        button.isEnabled = enabled
        let baseTooltip = NSLocalizedString("More Spaces", comment: "")
        button.toolTip = displayOrdinal.map { String(format: NSLocalizedString("%@ (Display %d)", comment: ""), baseTooltip, $0) } ?? baseTooltip
        button.setAccessibilityLabel(button.toolTip)
        let activeInOverflow = indexes.contains { spaceIds[$0 - 1] == activeSpaceId }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: activeInOverflow ? .semibold : .medium)
        let color = segmentColor()
        button.attributedTitle = NSAttributedString(string: "…", attributes: [.font: font, .foregroundColor: color])
        button.layer?.backgroundColor = activeInOverflow ? color.withAlphaComponent(activeSegmentFill).cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = color.withAlphaComponent(borderAlpha(isLeadingGroup: !secondaryGroup)).cgColor
        button.layer?.borderWidth = 1
        overflowIndexesByButton[ObjectIdentifier(button)] = indexes
        return button
    }

    private static func styleSpaceButton(_ button: NSButton, _ index: Int, _ active: Bool, _ enabled: Bool, _ secondaryGroup: Bool, _ displayOrdinal: Int? = nil) {
        button.tag = index
        button.isEnabled = enabled
        let baseTooltip = String(format: NSLocalizedString("Switch to Space %d", comment: ""), index)
        button.toolTip = displayOrdinal.map { String(format: NSLocalizedString("%@ (Display %d)", comment: ""), baseTooltip, $0) } ?? baseTooltip
        button.setAccessibilityLabel(button.toolTip)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: active ? .semibold : .medium)
        let color = segmentColor()
        button.attributedTitle = NSAttributedString(string: "\(index)", attributes: [.font: font, .foregroundColor: color])
        button.layer?.backgroundColor = active ? color.withAlphaComponent(activeSegmentFill).cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = color.withAlphaComponent(borderAlpha(isLeadingGroup: !secondaryGroup)).cgColor
        button.layer?.borderWidth = 1
    }

    /// Segments are only wired to the shared action register up to Space 9; overflow indexes beyond
    /// that reach the same underlying switch directly, since only a shortcut needs a registered action.
    private static var overflowIndexesByButton = [ObjectIdentifier: [Int]]()

    /// Switches the display the clicked segment belongs to, which is not necessarily the one the cursor
    /// is on.
    ///
    /// A gesture only ever reaches the active menubar display, so a click on another display's group used
    /// to be refused — silently at first, which cost fourteen clicks in a row before it was measured.
    /// Moving the Space layers reaches any display, so the refusal is gone. The gesture path stays for
    /// the display the cursor is on: it is the one that has been operated for months.
    private static func switchTo(_ index: Int, from sender: NSButton) {
        if !gestureWouldReach(sender), let groupUuid = sender.identifier?.rawValue,
           InstantSpaces.switchDirectly(to: index, on: groupUuid as ScreenUuid) {
            return
        }
        if index <= 9 {
            Actions.perform(.space(.index(index)))
        } else {
            InstantSpaces.perform(.index(index))
        }
    }

    @objc private static func spaceSegmentOnClick(_ sender: NSButton) {
        switchTo(sender.tag, from: sender)
    }

    @objc private static func spaceOverflowOnClick(_ sender: NSButton) {
        guard let indexes = overflowIndexesByButton[ObjectIdentifier(sender)] else { return }
        let menu = NSMenu()
        indexes.forEach { index in
            let item = menu.addItem(withTitle: String(format: NSLocalizedString("Space %d", comment: ""), index), action: #selector(spaceOverflowItemOnClick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            // a menu item has no identifier to carry the group, and the overflow of one display must not
            // switch another's
            item.representedObject = sender.identifier?.rawValue
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private static func spaceOverflowItemOnClick(_ sender: NSMenuItem) {
        if let groupUuid = sender.representedObject as? String,
           cursorIsNotOn(groupUuid), InstantSpaces.switchDirectly(to: sender.tag, on: groupUuid as ScreenUuid) {
            return
        }
        InstantSpaces.perform(.index(sender.tag))
    }

    private static func cursorIsNotOn(_ groupUuid: String) -> Bool {
        guard let cursorUuid = NSScreen.withMouse()?.cachedUuid() as String? else { return false }
        return cursorUuid != groupUuid
    }

    private static func isMainScreen(_ screen: NSScreen) -> Bool {
        guard let id = screen.number() else { return false }
        return CGDisplayIsMain(id) != 0
    }

    private static func gestureWouldReach(_ button: NSButton) -> Bool {
        guard let groupUuid = button.identifier?.rawValue, let cursorUuid = NSScreen.withMouse()?.cachedUuid() else { return true }
        return MenubarSpaceRow.gestureReachesGroup(groupIsUnderCursor: groupUuid == cursorUuid as String,
                                                separateSpaces: NSScreen.screensHaveSeparateSpaces)
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
