import Cocoa

/// A short message that appears below the menubar and disappears by itself. Used where an alert would
/// be disproportionate: the user did not do anything wrong and has nothing to confirm.
class TransientNotice: NSPanel {
    private static var shared: TransientNotice?
    private static let visibleDuration = TimeInterval(8)
    private static let fadeDuration = TimeInterval(0.4)
    private static let width = CGFloat(420)
    private static let padding = CGFloat(16)

    static func show(_ message: String) {
        DispatchQueue.main.async {
            shared?.dismiss()
            let notice = TransientNotice(message)
            shared = notice
            notice.orderFrontRegardless()
            notice.scheduleDismissal()
        }
    }

    private init(_ message: String) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let (view, height) = makeContentView(message)
        contentView = view
        setFrame(frameBelowMenubar(height), display: false)
    }

    private func makeContentView(_ message: String) -> (NSView, CGFloat) {
        let label = NSTextField(labelWithString: message)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = Self.width - 2 * Self.padding
        label.translatesAutoresizingMaskIntoConstraints = false
        let background = NSVisualEffectView()
        if #available(macOS 10.14, *) {
            background.material = .hudWindow
        }
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Self.padding),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -Self.padding),
            label.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.padding),
            label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -Self.padding),
        ])
        // measured against the final width, because the panel frame is set before layout runs
        let labelHeight = label.sizeThatFits(NSSize(width: Self.width - 2 * Self.padding, height: .greatestFiniteMagnitude)).height
        return (background, labelHeight + 2 * Self.padding)
    }

    private func frameBelowMenubar(_ height: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        return NSRect(x: visible.maxX - Self.width - 20, y: visible.maxY - height - 12, width: Self.width, height: height)
    }

    private func scheduleDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration) { [weak self] in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.orderOut(nil)
            if Self.shared === self { Self.shared = nil }
        }
    }
}
