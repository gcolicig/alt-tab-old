import CoreGraphics
import Foundation

/// Which window a cursor operation acts on, or a deliberate refusal. The backlog is explicit that residual
/// uncertainty means no action: mutating the wrong window of a foreign app is worse than doing nothing.
enum CursorWindowResolution: Equatable {
    case resolved(CGWindowID)
    case refused(CursorWindowRefusal)
}

enum CursorWindowRefusal: String, Equatable {
    case nothingUnderCursor
    case ambiguousBoundsMatch
}

/// The outcome of each stage of the identification chain, gathered by the impure resolver. Kept as plain
/// data so the ordering between the stages can be tested without a running window server.
struct CursorWindowCandidates: Equatable {
    var elementWindow: CGWindowID?
    var focusedWindow: CGWindowID?
    var boundsMatches: [CGWindowID]

    init(elementWindow: CGWindowID? = nil, focusedWindow: CGWindowID? = nil, boundsMatches: [CGWindowID] = []) {
        self.elementWindow = elementWindow
        self.focusedWindow = focusedWindow
        self.boundsMatches = boundsMatches
    }
}

enum CursorWindowResolutionPolicy {
    /// Order per backlog section 1: element under the cursor first, focused window only on failure, a
    /// bounds match only after that, and only when it is unique.
    static func resolve(_ candidates: CursorWindowCandidates) -> CursorWindowResolution {
        if let window = candidates.elementWindow { return .resolved(window) }
        if let window = candidates.focusedWindow { return .resolved(window) }
        guard !candidates.boundsMatches.isEmpty else { return .refused(.nothingUnderCursor) }
        guard candidates.boundsMatches.count == 1 else { return .refused(.ambiguousBoundsMatch) }
        return .resolved(candidates.boundsMatches[0])
    }
}

/// Q-06: during a drag the event callback publishes only the newest target rect, and at most one AX write
/// is outstanding. Intermediate frames are dropped rather than queued, otherwise a slow app builds a
/// backlog that keeps moving its window after the mouse has stopped.
struct AxWriteCoalescer {
    /// 60 Hz upper bound; the backlog asks for 30 to 60.
    static let defaultMinimumInterval = 1.0 / 60

    let minimumInterval: Double
    private(set) var inFlight: CGRect?
    private(set) var pending: CGRect?
    private var lastWriteTime = -Double.infinity

    init(minimumInterval: Double = defaultMinimumInterval) {
        self.minimumInterval = minimumInterval
    }

    /// Returns the rect to write now, or nil to hold it until the current write finishes or the rate allows.
    mutating func submit(_ target: CGRect, now: Double) -> CGRect? {
        guard inFlight == nil, now - lastWriteTime >= minimumInterval else {
            pending = target
            return nil
        }
        return start(target, now)
    }

    /// The outstanding write finished. Returns the next rect if one is due.
    mutating func completed(now: Double) -> CGRect? {
        inFlight = nil
        guard let next = pending, now - lastWriteTime >= minimumInterval else { return nil }
        pending = nil
        return start(next, now)
    }

    /// Mouseup: the final frame is the one the user actually chose, so it bypasses the rate limit. Without
    /// this a drag that ends while a frame is held would leave the window one step behind.
    mutating func flush(now: Double) -> CGRect? {
        guard inFlight == nil, let next = pending else { return nil }
        pending = nil
        return start(next, now)
    }

    private mutating func start(_ target: CGRect, _ now: Double) -> CGRect {
        inFlight = target
        lastWriteTime = now
        return target
    }
}

/// Q-07: without this, an app that silently clamps or ignores a frame is indistinguishable from a bug in
/// our own geometry. Bounded so a long drag cannot grow it without limit.
struct AxDiagnosticEntry: Equatable {
    let windowId: CGWindowID
    let bundleId: String
    let displayIndex: Int
    let proposed: CGRect
    /// nil when the write failed or the window refused to report a frame back.
    let result: CGRect?

    var wasHonored: Bool {
        guard let result = result else { return false }
        return result == proposed
    }
}

struct AxDiagnosticsRing {
    static let defaultCapacity = 256

    let capacity: Int
    private(set) var entries = [AxDiagnosticEntry]()

    init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    mutating func record(_ entry: AxDiagnosticEntry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    /// The interesting entries when diagnosing an app-compatibility report: everything the app did not
    /// apply exactly as proposed.
    var deviations: [AxDiagnosticEntry] {
        entries.filter { !$0.wasHonored }
    }
}
