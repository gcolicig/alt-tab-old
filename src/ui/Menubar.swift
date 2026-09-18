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
    /// One entry per display group, in the status button's coordinates. Kept so a window drag can name the
    /// display a drop landed on instead of always taking the next one in physical order.
    private static var groupBoundsInButton = [(ScreenUuid, CGRect)]()

    /// One clickable segment of the rendered row, in the status button's coordinates. The row is drawn as a
    /// single image (see refreshSpaces), so a click on the button maps to a segment by position here instead
    /// of hitting a live NSButton.
    private struct SegmentTarget {
        let rect: CGRect
        let displayUuid: String
        let spaceIndex: Int
        let overflowIndexes: [Int]?
    }
    private static var segmentTargets = [SegmentTarget]()
    private static var muteTargets = [(rect: CGRect, icon: MuteIcon)]()
    private static let muteIconWidth = CGFloat(22)

    private struct SpaceGroup {
        let displayUuid: ScreenUuid
        let spaceIds: [CGSSpaceID]
        let activeSpaceId: CGSSpaceID?
    }

    static func initialize() {
        let permissionCalloutMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        permissionCalloutMenuItem.view = PermissionCallout()
        let calloutSeparator = NSMenuItem.separator()
        permissionCalloutMenuItems = [permissionCalloutMenuItem, calloutSeparator]
        menu = MenubarMenu.shared.build()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button!.target = self // NSStatusItem.target was deprecated in 10.14
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

    /// Leaves the row's own clicks to the row.
    ///
    /// The status button fires on mouse *down* and the segments are its subviews, so the icon's handler
    /// ran first on every segment click: it opened the context menu, and its `refreshSpaces` tore the
    /// segment out from under the mouse before the button could complete, swallowing the click. That is
    /// the same teardown the restyling path below already guards against.
    /// The display whose group sits under this Quartz point, if the row is showing one there.
    ///
    /// The row is rendered inside the status button, whose window frame is in AppKit coordinates while a
    /// drag reports the cursor in Quartz. The flip happens here so callers can stay in one space.
    static func displayGroup(atQuartzPoint point: CGPoint) -> ScreenUuid? {
        guard !groupBoundsInButton.isEmpty,
              let primaryFrame = NSScreen.screens.first?.frame,
              let window = statusItem?.button?.window else { return nil }
        let windowFrame = window.frame
        return groupBoundsInButton.first { _, bounds in
            let quartzY = primaryFrame.maxY - (windowFrame.minY + bounds.maxY)
            let quartzRect = CGRect(x: windowFrame.minX + bounds.minX, y: quartzY, width: bounds.width, height: bounds.height)
            return quartzRect.contains(point)
        }?.0
    }

    /// Handles a left click that landed on a rendered segment, if any. The row is one image, so the click is
    /// mapped to a segment by position. Returns false when the click was on the icon or empty area, so the
    /// icon's own behaviour (menu or switcher) runs.
    private static func handleSegmentClick() -> Bool {
        guard let button = statusItem?.button, let event = NSApp.currentEvent, event.type == .leftMouseDown else { return false }
        let point = button.convert(event.locationInWindow, from: nil)
        if let mute = muteTargets.first(where: { $0.rect.contains(point) }) {
            MicMuteIndicator.unmute(mute.icon)
            return true
        }
        guard let target = segmentTargets.first(where: { $0.rect.contains(point) }) else { return false }
        // a synthetic Space switch reaches only the display the cursor is on, so a click on another display's
        // group is refused with the same notice the live buttons showed
        if let cursorUuid = NSScreen.withMouse()?.cachedUuid(),
           !MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: target.displayUuid == cursorUuid as String,
                                             separateSpaces: NSScreen.screensHaveSeparateSpaces) {
            TransientNotice.show(crossDisplayTooltip())
            return true
        }
        if let overflowIndexes = target.overflowIndexes {
            showOverflowMenu(overflowIndexes, atX: point.x)
        } else if target.spaceIndex <= 9 {
            Actions.perform(.space(.index(target.spaceIndex)))
        } else {
            InstantSpaces.perform(.index(target.spaceIndex))
        }
        return true
    }

    private static func showOverflowMenu(_ indexes: [Int], atX x: CGFloat) {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        indexes.forEach { index in
            let item = menu.addItem(withTitle: String(format: NSLocalizedString("Space %d", comment: ""), index), action: #selector(spaceOverflowItemOnClick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
        }
        menu.popUp(positioning: nil, at: NSPoint(x: x, y: button.bounds.height), in: button)
    }

    @objc static func statusItemOnClick() {
        if handleSegmentClick() { return }
        refreshSpaces()
        // NSApp.currentEvent == nil if the icon is "clicked" through VoiceOver
        if let type = NSApp.currentEvent?.type, type != .leftMouseDown {
            App.showUiFromShortcut0()
        } else {
            // popUpMenu was deprecated in 10.14. Pop the menu at the button instead of assigning
            // statusItem.menu, so the click paths handled above keep control of when the menu opens.
            if let button = statusItem.button {
                Menubar.menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
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
        // keyed by object address, so an entry outliving its button is not merely wasted memory: a later
        // allocation landing on the same address would inherit the old Space indexes and open the wrong
        // overflow menu. The row is torn down here, so this is where the table stops being true.
        overflowIndexesByButton.removeAll()
        groupBoundsInButton.removeAll()
        segmentTargets.removeAll()
        muteTargets.removeAll()
        statusButton.image = preferredIcon()
        statusItem.length = NSStatusItem.squareLength
        statusButton.alignment = .center
        statusButton.setAccessibilityLabel(App.name)
        guard Preferences.menubarIconShown else { return }
        let muteIcons = MicMuteIndicator.rowIcons
        let groups = Preferences.spacesInMenubarShown ? spaceGroups() : []
        guard !groups.isEmpty || !muteIcons.isEmpty else { return }
        statusButton.setAccessibilityLabel(rowAccessibilityLabel(groups, muteIcons))
        let switchingEnabled = InstantSpaces.runtimeAvailability().isAvailable
        let cursorUuid = NSScreen.withMouse()?.cachedUuid()
        // the row must never collapse: the status button can still be unsized the first time this runs,
        // and since the icon moves into a subview here, a zero height renders as an empty menubar slot.
        // Beyond that the button's own height wins: `thickness` reports 22 on a menubar that is 32pt tall,
        // and taking the larger of the two placed the row above the button's centre.
        let rowHeight = statusButton.bounds.height > 0 ? statusButton.bounds.height : NSStatusBar.system.thickness
        let totalWidth = groups.isEmpty ? 0 : MenubarSpaceRow.totalWidth(groups.map { $0.spaceIds.count })
        // mute icons sit at the right end, after the Spaces: next to the AltTab+ icon they caught clicks
        // meant for the icon, and a mis-click unmuted (reported 2026-09-17)
        let muteWidth = CGFloat(muteIcons.count) * muteIconWidth
        let spacesX = iconWidth
        // the container carries its final frame before any segment goes in, like the single-row version did
        let container = SpaceSegmentsView(frame: NSRect(x: spacesX, y: 0, width: totalWidth, height: rowHeight))
        var x = CGFloat(0)
        var groupBounds = [(ScreenUuid, CGRect)]()
        groups.enumerated().forEach { groupOffset, group in
            if groupOffset > 0 {
                x += groupGap
                container.addSubview(groupDivider(x: x, height: rowHeight))
                x += groupGap
            }
            let groupStart = x
            x += addGroupSegments(group, startX: x, height: rowHeight, switchingEnabled: switchingEnabled,
                                   isCursorGroup: MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: cursorUuid == nil || cursorUuid == group.displayUuid,
                                                                                  separateSpaces: NSScreen.screensHaveSeparateSpaces),
                                   displayOrdinal: groups.count > 1 ? groupOffset + 1 : nil, into: container)
            // recorded in the button's own coordinates, so a drag can ask which display a drop landed on
            groupBounds.append((group.displayUuid, CGRect(x: spacesX + groupStart, y: 0, width: x - groupStart, height: rowHeight)))
        }
        groupBoundsInButton = groupBounds
        let rowWidth = spacesX + totalWidth + muteWidth + 2
        statusItem.length = rowWidth
        // Render the icon and segments as one image instead of hosting live, translucent subviews. On macOS 26
        // the status item re-snapshots live translucent subviews on every frame to draw its menu-bar shadow,
        // which burned a CPU core at idle. A rendered image is snapshotted once. Clicks map to a segment by
        // position (handleSegmentClick), so switching and the window drag keep working.
        let row = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: rowHeight))
        let iconView = NSImageView(frame: MenubarSpaceRow.centeredRect(x: 4, width: 20, availableHeight: rowHeight, preferredHeight: MenubarSpaceRow.iconHeight))
        iconView.image = tintedMenubarIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        row.addSubview(iconView)
        muteIcons.enumerated().forEach { offset, icon in
            let x = spacesX + totalWidth + CGFloat(offset) * muteIconWidth
            let view = NSImageView(frame: MenubarSpaceRow.centeredRect(x: x + 2, width: muteIconWidth - 4, availableHeight: rowHeight, preferredHeight: MenubarSpaceRow.iconHeight))
            view.image = tinted(icon.image)
            view.imageScaling = .scaleProportionallyUpOrDown
            row.addSubview(view)
            muteTargets.append((CGRect(x: x, y: 0, width: muteIconWidth, height: rowHeight), icon))
        }
        row.addSubview(container) // container already carries its x
        segmentTargets = collectSegmentTargets(container)
        statusButton.image = renderRowImage(row)
        statusButton.imageScaling = .scaleNone
        statusButton.alignment = .center
        customIconView = nil
        spaceSegmentsView = nil
    }

    /// VoiceOver reads the rendered row through this label. Per-segment accessibility children were measured
    /// on 2026-09-15 and do not work: the menu bar item exposes the button's label but drops its children,
    /// on the button and on its cell alike. So the row's information goes into one spoken summary.
    private static func rowAccessibilityLabel(_ groups: [SpaceGroup], _ muteIcons: [MuteIcon]) -> String {
        ([spacesAccessibilityLabel(groups)] + muteIcons.map { $0.label }).joined(separator: ", ")
    }

    private static func spacesAccessibilityLabel(_ groups: [SpaceGroup]) -> String {
        let summaries = groups.enumerated().map { offset, group -> String in
            let activeIndex = group.spaceIds.firstIndex { $0 == group.activeSpaceId }.map { $0 + 1 } ?? 0
            let summary = String(format: NSLocalizedString("Space %d of %d", comment: "Menubar VoiceOver label"), activeIndex, group.spaceIds.count)
            guard groups.count > 1 else { return summary }
            return String(format: NSLocalizedString("Display %d: %@", comment: "Menubar VoiceOver label"), offset + 1, summary)
        }
        return ([App.name] + summaries).joined(separator: ", ")
    }

    /// Bakes the menu-bar tint into the icon. A template image renders black off-screen, so the rendered row
    /// would show a black icon on a dark menu bar; tinting with the row's own text colour matches the bar.
    private static func tintedMenubarIcon() -> NSImage {
        tinted(preferredIcon()) ?? preferredIcon()
    }

    private static func tinted(_ image: NSImage?) -> NSImage? {
        guard let icon = image else { return nil }
        guard icon.isTemplate else { return icon }
        let tinted = NSImage(size: icon.size)
        tinted.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: icon.size))
        segmentColor().set()
        NSRect(origin: .zero, size: icon.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

    /// Records the clickable rect of every segment in the status button's coordinates, before the row is
    /// flattened to an image. The container sits at `iconWidth`, so each button's row x adds that offset.
    private static func collectSegmentTargets(_ container: NSView) -> [SegmentTarget] {
        container.subviews.compactMap { subview in
            guard let button = subview as? NSButton, let uuid = button.identifier?.rawValue else { return nil }
            let rect = CGRect(x: container.frame.minX + button.frame.minX, y: button.frame.minY, width: button.frame.width, height: button.frame.height)
            return SegmentTarget(rect: rect, displayUuid: uuid, spaceIndex: button.tag, overflowIndexes: overflowIndexesByButton[ObjectIdentifier(button)])
        }
    }

    /// Renders a view tree to an image through a throwaway offscreen window. A window-less view can drop the
    /// layer styling of the segment buttons under cacheDisplay, so the row gets a real backing to draw into.
    private static func renderRowImage(_ view: NSView) -> NSImage {
        let window = NSWindow(contentRect: view.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return NSImage(size: view.bounds.size) }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// Adds the segments for one display group and returns the width consumed. `displayOrdinal` is only
    /// set when more than one group is shown, so VoiceOver can name which display a segment belongs to.
    ///
    /// `isCursorGroup` only dims the segments, it no longer disables them. It is captured when the row is
    /// built, but the cursor moves between displays without rebuilding it, so a stale `false` left the
    /// segments of the display the user was actually on dead to the click. `spaceSegmentOnClick` already
    /// gates on the live cursor position, which is the authoritative check.
    private static func addGroupSegments(_ group: SpaceGroup, startX: CGFloat, height: CGFloat, switchingEnabled: Bool,
                                          isCursorGroup: Bool, displayOrdinal: Int?, into container: NSView) -> CGFloat {
        let directCount = MenubarSpaceRow.directSegmentCount(group.spaceIds.count)
        let hasOverflow = MenubarSpaceRow.hasOverflow(group.spaceIds.count)
        (0..<directCount).forEach { offset in
            let button = spaceButton(offset + 1, group.spaceIds[offset] == group.activeSpaceId, switchingEnabled, !isCursorGroup, displayOrdinal, group.displayUuid)
            button.frame = MenubarSpaceRow.centeredRect(x: startX + CGFloat(offset) * segmentWidth + 2, width: segmentWidth - 4, availableHeight: height, preferredHeight: MenubarSpaceRow.segmentHeight)
            container.addSubview(button)
        }
        guard hasOverflow else { return CGFloat(directCount) * segmentWidth }
        let overflowIndexes = MenubarSpaceRow.overflowIndexes(group.spaceIds.count)
        let overflowButton = overflowButton(overflowIndexes, group.spaceIds, group.activeSpaceId, switchingEnabled, !isCursorGroup, displayOrdinal, group.displayUuid)
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
    /// Updates only the dimming, from the live cursor position.
    ///
    /// A segment of another display cannot be switched, because the synthetic gesture carries no target
    /// display. That refusal is correct, but it was silent: the dimming that announces it was computed
    /// when the row was last built, and the cursor crosses displays without any Space change to rebuild
    /// on. Fourteen consecutive clicks were logged against an unreachable group with no feedback at all.
    /// Restyling in place rather than rebuilding avoids tearing the buttons out from under the mouse.
    ///
    /// The frame and the description both carry reachability, so both are refreshed here. Updating only the
    /// frame left the tooltip and the accessibility label stating the opposite of what the row showed, which
    /// reintroduced the silent refusal for anyone reading the row by hover or with VoiceOver instead of by eye.
    static func refreshReachabilityHint() {
        guard let container = spaceSegmentsView else { return }
        let cursorUuid = NSScreen.withMouse()?.cachedUuid() as String?
        let separateSpaces = NSScreen.screensHaveSeparateSpaces
        let color = segmentColor()
        container.subviews.compactMap { $0 as? NSButton }.forEach { button in
            guard let groupUuid = button.identifier?.rawValue else { return }
            let underCursor = cursorUuid == nil || cursorUuid == groupUuid
            let reachable = MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: underCursor, separateSpaces: separateSpaces)
            button.layer?.borderColor = color.withAlphaComponent(borderAlpha(reachable: reachable)).cgColor
            // the overflow segment stands for several Spaces, so it has no single index to name
            let isOverflow = overflowIndexesByButton[ObjectIdentifier(button)] != nil
            let tooltip = segmentTooltip(crossDisplay: !reachable, index: isOverflow ? nil : button.tag,
                                         displayOrdinal: displayOrdinal(of: groupUuid))
            button.toolTip = tooltip
            button.setAccessibilityLabel(tooltip)
        }
    }


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

    /// The AltTab+ glyph: a focused window with a title bar, and a strip of a window behind it on each
    /// side. It is drawn instead of loaded, so every edge sits on whole points and stays sharp at 1x and 2x;
    /// the first asset had edges at fractions of a point and looked uneven. The title bar is darker than
    /// the body on a light menu bar and lighter on a dark one, so it never merges with the bar.
    private static func focusGlyph(dark: Bool) -> NSImage {
        let body = NSColor(white: 0x6E / 255.0, alpha: 1)
        let titleBar = NSColor(white: CGFloat(dark ? 0x9A : 0x45) / 255.0, alpha: 1)
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            body.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 4, width: 2, height: 14), xRadius: 1, yRadius: 1).fill()
            NSBezierPath(roundedRect: NSRect(x: 20, y: 4, width: 2, height: 14), xRadius: 1, yRadius: 1).fill()
            let front = NSBezierPath(roundedRect: NSRect(x: 3, y: 2, width: 16, height: 18), xRadius: 2, yRadius: 2)
            front.fill()
            NSGraphicsContext.saveGraphicsState()
            front.setClip()
            titleBar.setFill()
            NSRect(x: 3, y: 17, width: 16, height: 3).fill()
            NSRect(x: 3, y: 16, width: 16, height: 1).fill(using: .clear)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func preferredIcon() -> NSImage {
        let index = Preferences.menubarIcon.indexAsString
        if index == "0" {
            return focusGlyph(dark: NSApp.effectiveAppearance.getThemeName() == .dark)
        }
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
    private static func borderAlpha(reachable: Bool) -> CGFloat {
        reachable ? 0.55 : 0.16
    }

    /// Carries the active Space on its own now that the frame no longer does, so it has to be legible
    /// rather than a hint.
    private static let activeSegmentFill = CGFloat(0.22)

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
        button.toolTip = segmentTooltip(crossDisplay: crossDisplay, index: nil, displayOrdinal: displayOrdinal)
        button.setAccessibilityLabel(button.toolTip)
        let activeInOverflow = indexes.contains { spaceIds[$0 - 1] == activeSpaceId }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: activeInOverflow ? .semibold : .medium)
        let color = segmentColor()
        button.attributedTitle = NSAttributedString(string: "…", attributes: [.font: font, .foregroundColor: color])
        button.layer?.backgroundColor = activeInOverflow ? color.withAlphaComponent(activeSegmentFill).cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = color.withAlphaComponent(borderAlpha(reachable: !crossDisplay)).cgColor
        button.layer?.borderWidth = 1
        overflowIndexesByButton[ObjectIdentifier(button)] = indexes
        return button
    }

    private static func styleSpaceButton(_ button: NSButton, _ index: Int, _ active: Bool, _ enabled: Bool, _ crossDisplay: Bool, _ displayOrdinal: Int? = nil) {
        button.tag = index
        button.isEnabled = enabled
        button.toolTip = segmentTooltip(crossDisplay: crossDisplay, index: index, displayOrdinal: displayOrdinal)
        button.setAccessibilityLabel(button.toolTip)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: active ? .semibold : .medium)
        let color = segmentColor()
        button.attributedTitle = NSAttributedString(string: "\(index)", attributes: [.font: font, .foregroundColor: color])
        button.layer?.backgroundColor = active ? color.withAlphaComponent(activeSegmentFill).cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = color.withAlphaComponent(borderAlpha(reachable: !crossDisplay)).cgColor
        button.layer?.borderWidth = 1
    }

    /// Segments are only wired to the shared action register up to Space 9; overflow indexes beyond
    /// that reach the same underlying switch directly, since only a shortcut needs a registered action.
    private static var overflowIndexesByButton = [ObjectIdentifier: [Int]]()

    /// A refused click must say so. Measured on 2026-08-06: fourteen clicks in a row went to a group of
    /// another display and did nothing at all, because the refusal was silent and the hint that should
    /// have warned was stale. Remote switching is not an option — the Dock applies a swipe to the active
    /// menubar display, which nothing about the event or the cursor can redirect (S-10).
    private static func refuseCrossDisplayClick(_ sender: NSButton) -> Bool {
        guard !cursorMatchesGroup(sender) else { return false }
        refreshReachabilityHint()
        TransientNotice.show(crossDisplayTooltip())
        return true
    }

    @objc private static func spaceSegmentOnClick(_ sender: NSButton) {
        guard !refuseCrossDisplayClick(sender) else { return }
        if sender.tag <= 9 {
            Actions.perform(.space(.index(sender.tag)))
        } else {
            InstantSpaces.perform(.index(sender.tag))
        }
    }

    @objc private static func spaceOverflowOnClick(_ sender: NSButton) {
        guard !refuseCrossDisplayClick(sender), let indexes = overflowIndexesByButton[ObjectIdentifier(sender)] else { return }
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
    private static func isMainScreen(_ screen: NSScreen) -> Bool {
        guard let id = screen.number() else { return false }
        return CGDisplayIsMain(id) != 0
    }

    private static func cursorMatchesGroup(_ button: NSButton) -> Bool {
        guard let groupUuid = button.identifier?.rawValue, let cursorUuid = NSScreen.withMouse()?.cachedUuid() else { return true }
        return MenubarSpaceRow.clickIsReachable(groupIsUnderCursor: groupUuid == cursorUuid as String,
                                                separateSpaces: NSScreen.screensHaveSeparateSpaces)
    }

    private static func crossDisplayTooltip() -> String {
        NSLocalizedString("Move the cursor to this screen to switch its Spaces.", comment: "")
    }

    /// The one place a segment's spoken and hovered description is composed, so the build and the refresh
    /// below cannot drift apart. `index` is nil for the overflow segment, which stands for several Spaces.
    private static func segmentTooltip(crossDisplay: Bool, index: Int?, displayOrdinal: Int?) -> String {
        let base: String
        if crossDisplay {
            base = crossDisplayTooltip()
        } else if let index {
            base = String(format: NSLocalizedString("Switch to Space %d", comment: ""), index)
        } else {
            base = NSLocalizedString("More Spaces", comment: "")
        }
        guard let displayOrdinal else { return base }
        return String(format: NSLocalizedString("%@ (Display %d)", comment: ""), base, displayOrdinal)
    }

    /// Recomputed from the recorded group order rather than stored per button, so it cannot outlive the row
    /// it describes. Matches the rule used when building: an ordinal only means something with several groups.
    private static func displayOrdinal(of groupUuid: String) -> Int? {
        guard groupBoundsInButton.count > 1,
              let index = groupBoundsInButton.firstIndex(where: { $0.0 as String == groupUuid }) else { return nil }
        return index + 1
    }
}

private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// Carries the Space segments and refreshes their dimming when the mouse arrives.
///
/// Which segments are reachable depends on the display under the cursor, and the cursor moves between
/// displays without any event the row was listening to. Arriving on the row is the last moment before
/// the reachability matters, and the only one at which updating it costs nothing.
private final class SpaceSegmentsView: NSView {
    private var cursorTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        Menubar.refreshReachabilityHint()
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
