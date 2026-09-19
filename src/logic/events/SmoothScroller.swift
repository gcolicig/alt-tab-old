import Cocoa

/// Turns a discrete wheel notch into a short series of pixel scroll events, at ~120 Hz, following the
/// ease-out curve in `SmoothScrollStep`. All state lives on `queue`; `add` is the only entry point safe to
/// call from the tap thread, everything else runs on `queue` including the timer callback.
class SmoothScroller {
    /// Marks the pixel events this class posts, so the tap that reads them back can pass them straight
    /// through instead of smoothing an already-smoothed event into a loop. Distinct from
    /// `KeyboardEvents.syntheticCapsLockMarker` so the two synthetic sources can never collide.
    static let marker: Int64 = 0x414C54534D4F4F54

    private static let tickInterval = 1.0 / 120

    private let queue = DispatchQueue(label: "SmoothScroller")
    private lazy var timer: DispatchSourceTimer = {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.tickInterval, repeating: Self.tickInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        return timer
    }()
    private var timerIsSuspended = true

    private var remainingX = 0.0
    private var remainingY = 0.0
    private var carryX = 0.0
    private var carryY = 0.0
    private var flags: CGEventFlags = []

    /// Queues a wheel notch's already-transformed pixel delta. Same-direction deltas accumulate; a delta
    /// opposite the remaining distance replaces it outright, so reversing the wheel reverses on the spot
    /// instead of first finishing the previous glide.
    func add(dx: Double, dy: Double, flags: CGEventFlags) {
        queue.async { [self] in
            self.flags = flags
            remainingX = Self.combine(remainingX, dx)
            remainingY = Self.combine(remainingY, dy)
            if timerIsSuspended {
                timerIsSuspended = false
                timer.resume()
            }
        }
    }

    /// Stops mid-glide and drops any queued distance: used when smoothing is turned off, safe mode kicks
    /// in, or the switcher starts wanting the tap. Leaving a suspended timer with stale state would resume
    /// on the next `add` and jump by however much was pending from before the stop.
    func stopAndClear() {
        queue.async { [self] in
            suspendIfNeeded()
            remainingX = 0
            remainingY = 0
            carryX = 0
            carryY = 0
        }
    }

    private func suspendIfNeeded() {
        guard !timerIsSuspended else { return }
        timerIsSuspended = true
        timer.suspend()
    }

    private func tick() {
        let duration = Preferences.smoothScrollDuration.seconds
        let stepX = SmoothScrollStep.next(remaining: remainingX, dt: Self.tickInterval, duration: duration, carry: carryX)
        let stepY = SmoothScrollStep.next(remaining: remainingY, dt: Self.tickInterval, duration: duration, carry: carryY)
        remainingX = stepX.remaining
        carryX = stepX.carry
        remainingY = stepY.remaining
        carryY = stepY.carry
        if stepX.emit != 0 || stepY.emit != 0 {
            post(dx: stepX.emit, dy: stepY.emit)
        }
        if remainingX == 0 && remainingY == 0 {
            suspendIfNeeded()
        }
    }

    private func post(dx: Int, dy: Int) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else { return }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cgSessionEventTap)
    }

    /// A same-sign delta adds to the remaining distance; an opposite-sign delta (a reversal, or an
    /// overshoot past zero) discards the old remaining distance and starts fresh from the new delta.
    private static func combine(_ remaining: Double, _ delta: Double) -> Double {
        guard delta != 0 else { return remaining }
        return (remaining == 0 || (remaining > 0) == (delta > 0)) ? remaining + delta : delta
    }
}
