import Cocoa

/// The compact overlay that lists which keys may follow the current Leader sequence. Like the shortcut
/// clues panel it never takes focus, so arming and walking a sequence does not disturb the app in front.
/// A plain AppKit panel on purpose — the template (`mikker/LeaderKey`) uses SwiftUI, which the rest of the
/// app does not.
class LeaderPanel: NSPanel {
    struct Option {
        let key: String
        let label: String
        let isGroup: Bool
    }

    private static var shared: LeaderPanel?
    private static let padding = CGFloat(16)
    private static let keyColumnWidth = CGFloat(64)

    static func show(_ options: [Option]) {
        let panel = shared ?? LeaderPanel()
        shared = panel
        panel.render(options)
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

    private func render(_ options: [Option]) {
        let body = options.isEmpty
            ? LeaderPanel.message(NSLocalizedString("No Leader bindings configured.", comment: ""))
            : LeaderPanel.rows(options)
        let container = NSVisualEffectView()
        container.state = .active
        container.blendingMode = .behindWindow
        if #available(macOS 10.14, *) {
            container.material = .hudWindow
        }
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        body.setFrameOrigin(NSPoint(x: LeaderPanel.padding, y: LeaderPanel.padding))
        container.frame = NSRect(x: 0, y: 0,
                                 width: body.frame.width + LeaderPanel.padding * 2,
                                 height: body.frame.height + LeaderPanel.padding * 2)
        container.addSubview(body)
        contentView = container
        setContentSize(container.frame.size)
    }

    private static func rows(_ options: [Option]) -> NSView {
        let header = label(NSLocalizedString("Leader", comment: ""), font: .boldSystemFont(ofSize: 14), color: .labelColor)
        let rows: [NSView] = options.map { option in
            let key = label(option.key.isEmpty ? "?" : option.key,
                            font: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold), color: .labelColor)
            key.setFrameSize(NSSize(width: keyColumnWidth, height: key.fittingSize.height))
            let name = label(option.label, font: .systemFont(ofSize: 13),
                             color: option.isGroup ? .secondaryLabelColor : .labelColor)
            let row = NSStackView(views: [key, name])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 8
            return row
        }
        let stack = NSStackView(views: [header] + rows)
        stack.orientation = .vertical
        stack.alignment = .left
        stack.spacing = 6
        stack.layoutSubtreeIfNeeded()
        stack.setFrameSize(stack.fittingSize)
        return stack
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

    private func positionOnScreenUnderCursor() {
        guard let screen = NSScreen.withMouse() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = min(max(visible.midX - frame.width / 2, visible.minX), max(visible.maxX - frame.width, visible.minX))
        let y = min(max(visible.midY - frame.height / 2, visible.minY), max(visible.maxY - frame.height, visible.minY))
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
