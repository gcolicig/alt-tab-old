
class FrostedGlassEffectView: NSVisualEffectView, EffectView {
    convenience init(_: Int?) {
        self.init()
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        updateAppearance()
    }

    func updateAppearance() {
        material = Appearance.material
        updateRoundedCorners(Appearance.windowCornerRadius)
    }

    /// using layer!.cornerRadius works but the corners are aliased; this custom approach gives smooth rounded corners
    /// see https://stackoverflow.com/a/29386935/2249756
    private func updateRoundedCorners(_ cornerRadius: CGFloat) {
        if cornerRadius == 0 {
            maskImage = nil
        } else {
            let edgeLength = 2.0 * cornerRadius + 1.0
            let mask = NSImage(size: NSSize(width: edgeLength, height: edgeLength), flipped: false) { rect in
                let bezierPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                NSColor.black.set()
                bezierPath.fill()
                return true
            }
            mask.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
            mask.resizingMode = .stretch
            maskImage = mask
        }
    }
}

protocol EffectView: NSView {
    func updateAppearance()
}

func makeAppropriateEffectView() -> EffectView {
    Logger.debug { "Using FrostedGlassEffectView(nil)" }
    return FrostedGlassEffectView(nil)
}
