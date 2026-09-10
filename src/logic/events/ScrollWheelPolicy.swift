import Foundation

/// What the scroll-wheel tap does with one event. Pure on purpose: the tap callback runs on the input
/// thread for every scroll event on the machine, so the decision is made here, testable, and the callback
/// only carries it out.
enum ScrollWheelVerdict {
    /// Swallow it, so the app under the switcher does not scroll along with the gesture.
    case block
    /// Mirror the vertical axis before the focused app sees it.
    case invertVertical
    case passThrough
}

enum ScrollWheelPolicy {
    /// `absorbContinuous` is on while a switcher gesture is held, `rewriteDiscrete` while the user's scroll
    /// direction setting is active. They are independent: either one keeps the tap in the stream.
    ///
    /// macOS marks trackpad and Magic Mouse scrolling as continuous and a notched wheel as discrete, which
    /// is the only device distinction available without enumerating devices. Absorbing therefore only ever
    /// applies to continuous events, and inverting only to discrete ones — a user who inverts the wheel
    /// keeps the system's Natural Scrolling on the trackpad.
    static func verdict(isContinuous: Bool, absorbContinuous: Bool, rewriteDiscrete: Bool) -> ScrollWheelVerdict {
        if isContinuous {
            return absorbContinuous ? .block : .passThrough
        }
        return rewriteDiscrete ? .invertVertical : .passThrough
    }
}
