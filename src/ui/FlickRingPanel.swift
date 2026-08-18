import Cocoa

/// The ring drawn under the cursor while the FlickRing button is held. Four sectors, the chosen one lit; the
/// centre dead zone is drawn distinctly so that releasing there reads as "nothing chosen" rather than a
/// swallowed click. Plain AppKit drawing, no SwiftUI, to match the rest of the app. It never takes focus.
class FlickRingPanel: NSPanel {
    private static var shared: FlickRingPanel?
    private static let diameter = CGFloat(160)

    private let ringView = RingView(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))

    static func show(at cgLocation: CGPoint) {
        let panel = shared ?? FlickRingPanel()
        shared = panel
        panel.ringView.highlighted = nil
        panel.ringView.needsDisplay = true
        panel.centerOnCursor()
        panel.orderFrontRegardless()
    }

    static func highlight(_ direction: FlickDirection?) {
        guard let panel = shared, panel.ringView.highlighted != direction else { return }
        panel.ringView.highlighted = direction
        panel.ringView.needsDisplay = true
    }

    static func hide() {
        shared?.orderOut(nil)
        shared = nil
    }

    private init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: FlickRingPanel.diameter, height: FlickRingPanel.diameter),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = ringView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Cocoa screen coordinates (bottom-left origin). NSEvent.mouseLocation already gives them, so we avoid
    /// converting the tap's Quartz point across a multi-display layout.
    private func centerOnCursor() {
        let mouse = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(x: mouse.x - FlickRingPanel.diameter / 2, y: mouse.y - FlickRingPanel.diameter / 2))
    }

    private class RingView: NSView {
        var highlighted: FlickDirection?
        private let deadZoneRadius = CGFloat(18)

        override var isFlipped: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            let center = NSPoint(x: bounds.midX, y: bounds.midY)
            let radius = bounds.width / 2 - 4
            // sector centres, matching FlickDirection: right = 0°, up = 90°, counter-clockwise
            let sectors: [(FlickDirection, CGFloat)] = [(.right, 0), (.up, 90), (.left, 180), (.down, 270)]
            for (direction, mid) in sectors {
                let path = NSBezierPath()
                path.move(to: center)
                path.appendArc(withCenter: center, radius: radius, startAngle: mid - 45, endAngle: mid + 45)
                path.close()
                (direction == highlighted
                    ? NSColor.systemBlue.withAlphaComponent(0.85)
                    : NSColor.windowBackgroundColor.withAlphaComponent(0.55)).setFill()
                path.fill()
                NSColor.gridColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
            // the dead-zone hub: releasing here chooses nothing
            let hub = NSBezierPath(ovalIn: NSRect(x: center.x - deadZoneRadius, y: center.y - deadZoneRadius,
                                                  width: deadZoneRadius * 2, height: deadZoneRadius * 2))
            NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
            hub.fill()
            NSColor.gridColor.setStroke()
            hub.lineWidth = 1
            hub.stroke()
        }
    }
}
