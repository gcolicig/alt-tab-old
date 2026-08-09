import Cocoa

/// The target frame shown while an AltTab+ modifier drag is on a snap edge. Apple's own tiling preview
/// never appears during our drag, since an AX-driven move is not a title-bar drag, so without this the
/// user only learns where the window lands once they let go.
///
/// Styled after the system tiling preview: a translucent rounded rectangle with a thin border. It is a
/// non-activating panel that ignores every event, so it can never take focus, appear in the window cycle,
/// or swallow the drag it is describing.
class DragSnapOverlay: NSPanel {
    private static var shared: DragSnapOverlay?
    private static let cornerRadius = CGFloat(10)
    private let effectView = NSVisualEffectView()
    private let borderLayer = CALayer()

    /// Quartz rect, matching what the drag session computes. Converting here keeps the coordinate flip in
    /// one place instead of at every call site.
    static func show(quartzFrame: CGRect) {
        guard let primaryFrame = NSScreen.screens.first?.frame else { return }
        let appKitFrame = CGRect(x: quartzFrame.minX,
                                 y: primaryFrame.maxY - quartzFrame.maxY,
                                 width: quartzFrame.width,
                                 height: quartzFrame.height)
        let overlay = shared ?? DragSnapOverlay()
        shared = overlay
        overlay.setFrame(appKitFrame, display: true)
        overlay.applyAccessibilityPreferences()
        overlay.orderFrontRegardless()
    }

    static func hide() {
        shared?.orderOut(nil)
    }

    /// Released with the session rather than kept around: an overlay left alive across a display or Space
    /// change is how a stale frame ends up floating over an unrelated desktop.
    static func dismiss() {
        shared?.orderOut(nil)
        shared = nil
    }

    private init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        // above normal windows, but not above the menubar or system surfaces
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // never steals the drag it is describing
        becomesKeyOnlyIfNeeded = true
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        if #available(macOS 10.14, *) {
            effectView.material = .hudWindow
        }
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = DragSnapOverlay.cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        contentView = effectView
    }

    private func accentBorderColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor.controlAccentColor.withAlphaComponent(0.85)
        }
        return NSColor.selectedControlColor.withAlphaComponent(0.85)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Reduce Transparency replaces the vibrancy with a solid fill, Increase Contrast strengthens the
    /// border: both are the difference between a visible target and an invisible one for some users.
    private func applyAccessibilityPreferences() {
        let workspace = NSWorkspace.shared
        let reduceTransparency = workspace.accessibilityDisplayShouldReduceTransparency
        let increaseContrast = workspace.accessibilityDisplayShouldIncreaseContrast
        effectView.state = reduceTransparency ? .inactive : .active
        effectView.layer?.backgroundColor = reduceTransparency ? NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
        effectView.layer?.borderColor = increaseContrast ? NSColor.labelColor.cgColor : accentBorderColor().cgColor
        effectView.layer?.borderWidth = increaseContrast ? 2 : 1
    }
}
