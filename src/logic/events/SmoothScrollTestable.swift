import Cocoa

/// How long a single wheel notch takes to settle into place. The first test found 0.12 s and 0.22 s too
/// sluggish, so the scale now starts much shorter and has finer steps at the responsive end.
enum SmoothScrollDuration: String, CaseIterable {
    case quick
    case smooth
    case gliding
    case floating

    var seconds: Double {
        switch self {
            case .quick: return 0.07
            case .smooth: return 0.17
            case .gliding: return 0.26
            case .floating: return 0.40
        }
    }
}

/// Pure step math for `SmoothScroller`. Kept free of CGEvent/threading so it can be unit tested directly:
/// given a remaining distance and a frame's time slice, how many whole pixels does this frame emit, and
/// what carries over.
enum SmoothScrollStep {
    /// Below this many pixels, the animation is considered finished and emits whatever remains instead of
    /// spending more frames closing an imperceptible gap.
    static let finishThreshold = 1.0

    /// Exponential ease-out: constant fraction of the remaining distance per second, tuned so `duration`
    /// covers ~95% of the initial distance (a fixed rate independent of `duration` would not do that).
    /// `carry` accumulates the fractional pixels a frame doesn't have enough of to emit a whole pixel, so
    /// repeated small frames never lose distance to rounding.
    static func next(remaining: Double, dt: Double, duration: Double, carry: Double) -> (emit: Int, remaining: Double, carry: Double) {
        guard remaining != 0, duration > 0 else { return (0, 0, 0) }
        if abs(remaining) < finishThreshold {
            return (Int(remaining.rounded()), 0, 0)
        }
        // rate chosen so exp(-rate * duration) == 0.05, i.e. 95% covered within one duration
        let rate = -log(0.05) / duration
        let decay = exp(-rate * dt)
        let newRemaining = remaining * decay
        let wanted = (remaining - newRemaining) + carry
        let emit = Int(wanted.rounded(.towardZero))
        return (emit, newRemaining, wanted - Double(emit))
    }

    /// Whether a scroll-wheel event should be handed to the smoother instead of passed through with only
    /// the classic reverse/speed rewrite.
    static func shouldSmooth(isContinuous: Bool, flags: CGEventFlags, isSynthetic: Bool, enabled: Bool) -> Bool {
        guard enabled, !isContinuous, !isSynthetic else { return false }
        // apps read these modifiers as zoom/line-step gestures and expect unsmoothed, immediate deltas
        let zoomModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
        return flags.intersection(zoomModifiers).isEmpty
    }
}
