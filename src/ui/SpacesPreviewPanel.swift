import Cocoa

/// Opened from a Space segment in the menu bar. Shows one strip of Space tiles per display, arranged the way the
/// displays stand on the desk, in the spirit of Sysinternals Desktops. A tile is a miniature of its Space built
/// from the cached window thumbnails, since macOS does not render a Space that is not visible.
class SpacesPreviewPanel: NSPanel {
    private static var shared: SpacesPreviewPanel?
    private static var outsideClickMonitor: Any?
    private static var localClickMonitor: Any?
    private static let preferredTileHeight = CGFloat(190)
    private static let minimumTileHeight = CGFloat(80)
    private static let padding = CGFloat(12)
    private static let gap = CGFloat(10)


    static var isShowing: Bool { shared != nil }
    private static var rebuildIsScheduled = false

    static func toggle(anchoredTo button: NSStatusBarButton) {
        if isShowing {
            hide()
            return
        }
        let panel = SpacesPreviewPanel()
        shared = panel
        panel.anchorScreen = button.window?.screen
        panel.rebuild()
        panel.position(under: button)
        // the status item is still inside its own mouse-down tracking here; ordering the panel front from
        // that loop left it unable to receive clicks, so the panel is shown once the loop has ended
        DispatchQueue.main.async {
            guard shared === panel else { return }
            panel.orderFrontRegardless()
            panel.makeKey()
            // a click anywhere outside the app dismisses the panel, like a menu
            // AltTab+ is an accessory app, so this non-activating panel never receives the click itself: the
            // window server routes it past the app. The switcher solves this with a CGEvent tap; here the
            // monitor that dismisses the panel also delivers the click to the tile under the cursor.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                handleClick(at: NSEvent.mouseLocation)
            }
            // a global monitor never sees the app's own clicks, so a click on the status item or on another
            // AltTab+ window would leave the panel standing next to the menu it opened
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                handleClick(at: NSEvent.mouseLocation)
                return event
            }
        }
    }

    static func hide() {
        [outsideClickMonitor, localClickMonitor].compactMap { $0 }.forEach { NSEvent.removeMonitor($0) }
        outsideClickMonitor = nil
        localClickMonitor = nil
        shared?.orderOut(nil)
        shared = nil
    }

    /// Runs the tile under the cursor, or dismisses the panel when the click landed elsewhere.
    private static func handleClick(at screenPoint: NSPoint) {
        guard let panel = shared, panel.frame.contains(screenPoint) else {
            hide()
            return
        }
        let inWindow = NSPoint(x: screenPoint.x - panel.frame.minX, y: screenPoint.y - panel.frame.minY)
        guard let tile = panel.contentView?.hitTest(inWindow) as? SpaceTileView else { return }
        tile.onClick?()
    }

    /// A capture landed. The panel asks for the thumbnails of the windows it shows, and those arrive one by
    /// one, so the rebuilds are coalesced into one per runloop turn.
    static func noteThumbnailArrived() {
        guard isShowing, !rebuildIsScheduled else { return }
        rebuildIsScheduled = true
        DispatchQueue.main.async {
            rebuildIsScheduled = false
            guard let panel = shared else { return }
            let top = panel.frame.maxY
            panel.build()
            panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
        }
    }

    /// The active Space can change while the panel is open (keyboard shortcut, trackpad swipe).
    static func refreshIfShowing() {
        guard let panel = shared else { return }
        let top = panel.frame.maxY
        panel.rebuild()
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
    }

    private init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    // key, so Esc reaches cancelOperation; the panel is non-activating, so AltTab+ does not steal focus
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        SpacesPreviewPanel.hide()
    }

    // MARK: - Content

    private var tileHeight = SpacesPreviewPanel.preferredTileHeight
    /// The display the status item was clicked on. The panel is sized and placed against this one.
    private var anchorScreen: NSScreen?
    /// Every window drawn in the current content, for the thumbnail request.
    private var shownWindows = [Window]()

    /// Builds at the preferred tile size, then once more with smaller tiles when the panel is wider than the
    /// menu bar screen, so every Space stays on screen.
    private func rebuild() {
        tileHeight = SpacesPreviewPanel.preferredTileHeight
        let size = build()
        // the status item can sit on a narrower secondary display, so the limit comes from the display the
        // panel is anchored to, not from the primary one
        guard let maxWidth = (anchorScreen ?? NSScreen.screens.first).map({ $0.visibleFrame.width - 8 }),
              size.width > maxWidth else { return }
        tileHeight = max(SpacesPreviewPanel.minimumTileHeight, (tileHeight * maxWidth / size.width).rounded(.down))
        build()
    }

    @discardableResult
    private func build() -> CGSize {
        Spaces.refresh()
        let groups = Menubar.previewGroups()
        let screensByUuid = Dictionary(NSScreen.screens.compactMap { screen in screen.cachedUuid().map { ($0 as String, screen) } },
                                       uniquingKeysWith: { first, _ in first })
        let physicalHeights = Dictionary(groups.compactMap { group -> (String, CGFloat)? in
            screensByUuid[group.displayUuid as String].map { (group.displayUuid as String, SpacesPreviewPanel.physicalHeight($0)) }
        }, uniquingKeysWith: { first, _ in first })
        let tallest = physicalHeights.values.max() ?? 1
        shownWindows = []
        let strips = groups.compactMap { group -> (SpacesPreviewLayout.Display, NSView)? in
            guard let screen = screensByUuid[group.displayUuid as String] else { return nil }
            let scale = (physicalHeights[group.displayUuid as String] ?? tallest) / max(tallest, 1)
            return (SpacesPreviewLayout.Display(id: group.displayUuid as String, frame: screen.frame), stripView(group, screen, scale))
        }
        let stripsById = Dictionary(strips.map { ($0.0.id, $0.1) }, uniquingKeysWith: { first, _ in first })
        let rows = SpacesPreviewLayout.rows(strips.map { $0.0 }).map { row in row.compactMap { stripsById[$0] } }
        let content = layOut(rows)
        let background = NSVisualEffectView(frame: content.frame)
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        background.addSubview(content)
        contentView = background
        setContentSize(content.frame.size)
        // the switcher captures thumbnails only while it is open, so a preview opened on a fresh launch has
        // none; ask for the windows it shows, and rebuild as they arrive (noteThumbnailArrived)
        Windows.refreshThumbnailsAsync(shownWindows, .spacesPreview)
        return content.frame.size
    }

    /// Stacks the rows top to bottom, each row left to right. Rows are centred against the widest one, which keeps
    /// a single display above two side-by-side ones visually centred like on the desk.
    private func layOut(_ rows: [[NSView]]) -> NSView {
        let p = SpacesPreviewPanel.padding, gap = SpacesPreviewPanel.gap
        let rowSizes = rows.map { row in
            CGSize(width: row.map { $0.frame.width }.reduce(0, +) + gap * CGFloat(max(row.count - 1, 0)) * 2,
                   height: row.map { $0.frame.height }.max() ?? 0)
        }
        let width = (rowSizes.map { $0.width }.max() ?? 0) + p * 2
        let height = rowSizes.map { $0.height }.reduce(0, +) + gap * CGFloat(max(rows.count - 1, 0)) * 2 + p * 2
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        var top = height - p
        zip(rows, rowSizes).forEach { row, size in
            var x = (width - size.width) / 2
            row.forEach { strip in
                strip.setFrameOrigin(NSPoint(x: x, y: top - strip.frame.height))
                container.addSubview(strip)
                x += strip.frame.width + gap * 2
            }
            top -= size.height + gap * 2
        }
        return container
    }

    /// The tile keeps the display's aspect ratio, and its height follows the display's physical height: the
    /// larger monitor shows larger Spaces, as it does on the desk.
    private func stripView(_ group: Menubar.SpaceGroup, _ screen: NSScreen, _ heightScale: CGFloat) -> NSView {
        let height = (tileHeight * heightScale).rounded()
        let tileSize = CGSize(width: (height * screen.frame.width / max(screen.frame.height, 1)).rounded(), height: height)
        let count = group.spaceIds.count
        let width = CGFloat(count) * tileSize.width + CGFloat(max(count - 1, 0)) * SpacesPreviewPanel.gap
        let strip = NSView(frame: NSRect(x: 0, y: 0, width: width, height: tileSize.height))
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let screenQuartz = SpacesPreviewLayout.quartzFrame(cocoaFrame: screen.frame, primaryScreenHeight: primaryHeight)
        group.spaceIds.enumerated().forEach { offset, spaceId in
            let tile = SpaceTileView(frame: NSRect(x: CGFloat(offset) * (tileSize.width + SpacesPreviewPanel.gap), y: 0,
                                                   width: tileSize.width, height: tileSize.height))
            tile.configure(index: offset + 1, isActive: spaceId == group.activeSpaceId,
                           windows: windows(in: spaceId), screenFrame: screenQuartz)
            tile.onClick = { Menubar.switchToSpace(index: offset + 1, displayUuid: group.displayUuid, screen: screen) }
            strip.addSubview(tile)
        }
        return strip
    }

    /// The display's height in millimetres, which is what makes a bigger monitor show bigger Spaces. Falls back
    /// to the height in points when the display reports no physical size (some virtual displays report zero).
    private static func physicalHeight(_ screen: NSScreen) -> CGFloat {
        guard let id = screen.number() else { return screen.frame.height }
        let millimetres = CGDisplayScreenSize(id).height
        return millimetres > 0 ? millimetres : screen.frame.height
    }

    /// Back to front, so the most recently focused window is drawn last and ends on top.
    private func windows(in spaceId: CGSSpaceID) -> [Window] {
        let found = Windows.list
            .filter { !$0.isWindowlessApp && !$0.isMinimized && !$0.isHidden && $0.spaceIds.contains(spaceId) }
            .sorted { $0.lastFocusOrder > $1.lastFocusOrder }
        shownWindows.append(contentsOf: found)
        return found
    }

    private func position(under button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = anchorScreen ?? NSScreen.main else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        // clamp against the left edge last, so a panel still wider than the display stays reachable there
        // instead of being pushed off to the left by an inverted upper bound
        let x = max(min(buttonFrame.midX - frame.width / 2, visible.maxX - frame.width - 4), visible.minX + 4)
        setFrameTopLeftPoint(NSPoint(x: x, y: buttonFrame.minY - 4))
    }
}

/// One Space: a miniature of its windows, the Space number, and an accent border when it is the active one.
final class SpaceTileView: NSView {
    var onClick: (() -> Void)?
    private var isActive = false

    override var isFlipped: Bool { true }

    func configure(index: Int, isActive: Bool, windows: [Window], screenFrame: CGRect) {
        self.isActive = isActive
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        layer?.borderWidth = isActive ? 2 : 1
        layer?.borderColor = (isActive ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        windows.forEach { addWindow($0, screenFrame) }
        let number = NSTextField(labelWithString: String(index))
        number.font = .systemFont(ofSize: 11, weight: isActive ? .bold : .regular)
        number.textColor = .white
        number.drawsBackground = true
        number.backgroundColor = (isActive ? NSColor.controlAccentColor : NSColor.black).withAlphaComponent(0.6)
        number.sizeToFit()
        number.frame = NSRect(x: 4, y: 4, width: number.frame.width + 6, height: number.frame.height)
        number.alignment = .center
        addSubview(number)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(String(format: NSLocalizedString("Space %d", comment: ""), index))
    }

    private func addWindow(_ window: Window, _ screenFrame: CGRect) {
        guard let position = window.position, let size = window.size,
              let rect = SpacesPreviewLayout.windowRect(windowFrame: CGRect(origin: position, size: size), screenFrame: screenFrame, tileSize: bounds.size) else { return }
        let windowLayer = CALayer()
        windowLayer.frame = rect
        windowLayer.contentsGravity = .resizeAspectFill
        windowLayer.backgroundColor = NSColor.windowBackgroundColor.cgColor
        windowLayer.borderWidth = 0.5
        windowLayer.borderColor = NSColor.black.withAlphaComponent(0.4).cgColor
        switch window.thumbnail {
        case .cgImage(let image?)?:
            windowLayer.contents = image
        case .pixelBuffer(let buffer?)?:
            // a layer does not draw a CVPixelBuffer; its IOSurface it does (same as LightImageLayer)
            windowLayer.contents = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
        default:
            addIconLayer(window.application.icon, into: windowLayer)
        }
        layer?.addSublayer(windowLayer)
    }

    /// Fallback for a window never captured since launch: its app icon, centred.
    private func addIconLayer(_ icon: CGImage?, into windowLayer: CALayer) {
        guard let icon else { return }
        let side = min(windowLayer.bounds.width, windowLayer.bounds.height, 24)
        let iconLayer = CALayer()
        iconLayer.frame = CGRect(x: (windowLayer.bounds.width - side) / 2, y: (windowLayer.bounds.height - side) / 2, width: side, height: side)
        iconLayer.contents = icon
        windowLayer.addSublayer(iconLayer)
    }

    // mouseDown, not mouseUp: the panel does not activate the app, so the first click of a pair can be
    // consumed by the window before a mouseUp reaches the tile
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}
