import Cocoa

/// A crosshair overlay over every display. Dragging selects a rectangle; Escape or a click without a drag
/// cancels. The result is in global AppKit coordinates.
final class RegionSelection {
    private static var active: RegionSelection?
    private var panels = [NSPanel]()
    private let completion: (CGRect?, NSScreen?) -> Void

    static func run(_ completion: @escaping (CGRect?, NSScreen?) -> Void) {
        guard active == nil else { return }
        let selection = RegionSelection(completion)
        active = selection
        selection.show()
    }

    private init(_ completion: @escaping (CGRect?, NSScreen?) -> Void) {
        self.completion = completion
    }

    private func show() {
        panels = NSScreen.screens.map(makePanel)
        NSApp.activate(ignoringOtherApps: true)
        panels.forEach { $0.orderFrontRegardless() }
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        (panels.first { $0.screen == mouseScreen } ?? panels.first)?.makeKey()
    }

    private func makePanel(_ screen: NSScreen) -> NSPanel {
        let panel = SelectionPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.15)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.acceptsMouseMovedEvents = true
        let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.onFinish = { [weak self] rect in self?.finish(rect.map { $0.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY) }, screen) }
        panel.contentView = view
        return panel
    }

    private func finish(_ rect: CGRect?, _ screen: NSScreen) {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        RegionSelection.active = nil
        // the overlay must be gone from the screen before anything captures it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.completion(rect, rect == nil ? nil : screen) }
    }
}

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else { return }
        onFinish?(nil)
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let end = convert(event.locationInWindow, from: nil)
        onFinish?(start.flatMap { ScreenToolsFormat.selection(from: $0, to: end) })
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let start, let current, let rect = ScreenToolsFormat.selection(from: start, to: current, minimumSize: 1) else { return }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 1.5
        path.stroke()
    }
}
