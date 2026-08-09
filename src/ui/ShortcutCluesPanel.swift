import Cocoa

/// The overlay listing another app's shortcuts. It never takes focus, so the app whose shortcuts are shown
/// stays active and every keystroke reaches it unchanged — pressing one of the listed shortcuts runs it.
class ShortcutCluesPanel: NSPanel {
    private static var shared: ShortcutCluesPanel?
    private static let columnWidth = CGFloat(260)
    private static let maximumColumns = 4
    private static let padding = CGFloat(16)
    private static let keyColumnWidth = CGFloat(74)
    private static let keyToTitleSpacing = CGFloat(8)
    /// What is left of a column once the shortcut itself has its fixed share. The item title is the only
    /// part of a row whose length another app decides, so it is the only part that is capped.
    private static var titleMaximumWidth: CGFloat { columnWidth - keyColumnWidth - keyToTitleSpacing }

    enum Content {
        case shortcuts(MenuShortcutReader.Result, String)
        case empty(String)
        case permissionMissing
    }

    static func show(_ content: Content) {
        let panel = shared ?? ShortcutCluesPanel()
        shared = panel
        panel.render(content)
        panel.positionOnScreenUnderCursor()
        panel.orderFrontRegardless()
    }

    static func hide() {
        shared?.orderOut(nil)
        shared = nil
    }

    private init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func render(_ content: Content) {
        let body: NSView
        switch content {
            case .permissionMissing:
                body = ShortcutCluesPanel.message(NSLocalizedString("AltTab+ needs accessibility permission to read the menus of other apps.", comment: ""))
            case .empty(let appName):
                body = ShortcutCluesPanel.message(String(format: NSLocalizedString("%@ lists no keyboard shortcuts in its menus.", comment: ""), appName))
            case .shortcuts(let result, let appName):
                body = ShortcutCluesPanel.columns(result, appName)
        }
        let container = NSVisualEffectView()
        container.state = .active
        container.blendingMode = .behindWindow
        if #available(macOS 10.14, *) {
            container.material = .hudWindow
        }
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        body.setFrameOrigin(NSPoint(x: ShortcutCluesPanel.padding, y: ShortcutCluesPanel.padding))
        container.frame = NSRect(x: 0, y: 0,
                                 width: body.frame.width + ShortcutCluesPanel.padding * 2,
                                 height: body.frame.height + ShortcutCluesPanel.padding * 2)
        container.addSubview(body)
        contentView = container
        setContentSize(container.frame.size)
    }

    /// Grouped by menu, in menubar order, filling columns top to bottom. A truncated scan says so instead
    /// of quietly showing a shorter list.
    private static func columns(_ result: MenuShortcutReader.Result, _ appName: String) -> NSView {
        var groups = [(String, [MenuShortcut])]()
        result.shortcuts.forEach { shortcut in
            if let index = groups.firstIndex(where: { $0.0 == shortcut.menuTitle }) {
                groups[index].1.append(shortcut)
            } else {
                groups.append((shortcut.menuTitle, [shortcut]))
            }
        }
        let columnCount = min(maximumColumns, max(1, Int(ceil(Double(groups.count) / 3))))
        let columnViews: [NSView] = (0..<columnCount).map { column in
            let stack = NSStackView(views: groups.enumerated()
                .filter { $0.offset % columnCount == column }
                .flatMap { group($0.element.0, $0.element.1) })
            stack.orientation = .vertical
            stack.alignment = .left
            stack.spacing = 6
            return stack
        }
        let content = NSStackView(views: columnViews)
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 24
        var views: [NSView] = [title(appName)]
        views.append(content)
        if let notice = MenuScanLimits.truncationNotice(scanned: result.scannedItems, wasTruncated: result.wasTruncated) {
            views.append(label(notice, font: .systemFont(ofSize: 11), color: .secondaryLabelColor))
        }
        let outer = NSStackView(views: views)
        outer.orientation = .vertical
        outer.alignment = .left
        outer.spacing = 12
        outer.layoutSubtreeIfNeeded()
        outer.setFrameSize(outer.fittingSize)
        return outer
    }

    private static func group(_ menuTitle: String, _ shortcuts: [MenuShortcut]) -> [NSView] {
        var views: [NSView] = [label(menuTitle, font: .boldSystemFont(ofSize: 12), color: .secondaryLabelColor)]
        views += shortcuts.map { shortcut in
            let key = label(shortcut.displayString, font: .monospacedDigitSystemFont(ofSize: 12, weight: .semibold), color: .labelColor)
            key.setFrameSize(NSSize(width: keyColumnWidth, height: key.fittingSize.height))
            let name = label(shortcut.itemTitle, font: .systemFont(ofSize: 12), color: .labelColor)
            // another app decides how long this is, and nothing else here limits the panel: a single long
            // item title would otherwise widen it past the screen it is centred on
            if name.frame.width > titleMaximumWidth {
                name.lineBreakMode = .byTruncatingTail
                name.cell?.truncatesLastVisibleLine = true
                name.setFrameSize(NSSize(width: titleMaximumWidth, height: name.frame.height))
            }
            let row = NSStackView(views: [key, name])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 8
            return row
        }
        return views
    }

    private static func title(_ appName: String) -> NSView {
        label(String(format: NSLocalizedString("Shortcuts in %@", comment: ""), appName),
              font: .boldSystemFont(ofSize: 14), color: .labelColor)
    }

    private static func message(_ text: String) -> NSView {
        let view = label(text, font: .systemFont(ofSize: 13), color: .labelColor)
        view.setFrameSize(view.fittingSize)
        return view
    }

    private static func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.sizeToFit()
        return field
    }

    /// Centred on the screen the cursor is on, like the other modules, but never past its edges: the panel
    /// is sized by another app's menu, so it can still come out larger than expected in one direction.
    private func positionOnScreenUnderCursor() {
        guard let screen = NSScreen.withMouse() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = min(max(visible.midX - frame.width / 2, visible.minX), max(visible.maxX - frame.width, visible.minX))
        let y = min(max(visible.midY - frame.height / 2, visible.minY), max(visible.maxY - frame.height, visible.minY))
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
