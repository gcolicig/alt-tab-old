import AppKit
import CoreGraphics
import Foundation

/// One modifier drag, start to finish. Move and modifier snapping share this session: the window is
/// resolved exactly once, and a single closing action applies either the freely dragged frame or the snap
/// target. Two competing trackers would each resolve their own window and disagree about which one wins.
enum DragSessionState: Equatable {
    case idle
    case armed
    case resolving
    case dragging
    case finishing
    case cancelled
}

enum DragSessionEvent: Equatable {
    case modifierEngaged
    case modifierReleased
    case mouseDown
    case windowResolved
    case windowUnresolved
    case mouseDragged
    case mouseUp
    /// Escape, Space or display change, lost accessibility permission, safe mode, emergency shortcut.
    case aborted
    case applied
}

enum DragSessionMachine {
    /// Returns the next state, or nil when the event does not apply and must be ignored rather than
    /// treated as an error.
    static func next(_ state: DragSessionState, _ event: DragSessionEvent) -> DragSessionState? {
        if case .aborted = event, isActive(state) { return .cancelled }
        switch (state, event) {
            case (.idle, .modifierEngaged): return .armed
            case (.armed, .modifierReleased): return .idle
            case (.armed, .mouseDown): return .resolving
            case (.resolving, .windowResolved): return .dragging
            // a refusal from the resolver ends the session silently: no action is the documented outcome
            case (.resolving, .windowUnresolved): return .idle
            case (.dragging, .mouseDragged): return .dragging
            case (.dragging, .mouseUp): return .finishing
            case (.finishing, .applied): return .idle
            case (.cancelled, .applied): return .idle
            // releasing the modifier mid-drag does not end the drag: the mouse button is what holds the
            // session, and dropping the window the moment a finger lifts would be unusable
            case (.dragging, .modifierReleased): return .dragging
            case (.resolving, .modifierReleased): return .resolving
            default: return nil
        }
    }

    static func isActive(_ state: DragSessionState) -> Bool {
        state == .armed || state == .resolving || state == .dragging
    }

    /// Only a session that reached `dragging` may write a frame; anything else must leave the window alone.
    static func mayApplyFrame(_ state: DragSessionState) -> Bool {
        state == .finishing
    }
}

/// The targets AltTab+ provides inside its own modifier drag. They exist because an AX-driven drag never
/// triggers Apple's title-bar tiling, so these three would otherwise be unreachable during such a drag.
/// Everything Tahoe already covers outside our drag stays untouched.
enum DragSnapTarget: Equatable {
    case none
    case leftHalf
    case rightHalf
    case fill
}

/// Coordinates here are Quartz, matching `CGEvent.location` and the AX position attribute: the origin is
/// the top-left of the primary display and y grows downward. So the top edge of a screen is `minY`, not
/// `maxY` — getting this backwards silently swaps the fill zone with the deliberately inert bottom edge.
struct DragSnapContext: Equatable {
    let cursor: CGPoint
    let visibleFrame: CGRect
    /// A shared edge continues onto another display, so crossing it is a normal cursor move and must not
    /// snap on distance alone.
    let hasNeighbourLeft: Bool
    let hasNeighbourRight: Bool
    let dwellElapsed: Double

    init(cursor: CGPoint, visibleFrame: CGRect, hasNeighbourLeft: Bool = false, hasNeighbourRight: Bool = false, dwellElapsed: Double = 0) {
        self.cursor = cursor
        self.visibleFrame = visibleFrame
        self.hasNeighbourLeft = hasNeighbourLeft
        self.hasNeighbourRight = hasNeighbourRight
        self.dwellElapsed = dwellElapsed
    }
}

enum DragSnapPolicy {
    static let edgeTolerance = CGFloat(3)
    static let sharedEdgeDwell = 0.2

    /// Which edge the cursor is on, ignoring whether that edge is currently usable. Separated from
    /// `target` so the caller can track how long the cursor has been on one edge without asking the same
    /// question twice with a fake dwell.
    static func edge(_ cursor: CGPoint, _ visibleFrame: CGRect) -> DragSnapTarget {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return .none }
        // the bottom edge (maxY in Quartz) collides with Dock auto-hide and magnification, so it carries
        // no zone at all; only the top edge fills
        if cursor.y <= visibleFrame.minY + edgeTolerance { return .fill }
        if cursor.x <= visibleFrame.minX + edgeTolerance { return .leftHalf }
        if cursor.x >= visibleFrame.maxX - edgeTolerance { return .rightHalf }
        return .none
    }

    static func target(_ context: DragSnapContext) -> DragSnapTarget {
        let edge = edge(context.cursor, context.visibleFrame)
        switch edge {
            case .none, .fill: return edge
            case .leftHalf: return isAvailable(shared: context.hasNeighbourLeft, dwell: context.dwellElapsed) ? edge : .none
            case .rightHalf: return isAvailable(shared: context.hasNeighbourRight, dwell: context.dwellElapsed) ? edge : .none
        }
    }

    private static func isAvailable(shared: Bool, dwell: Double) -> Bool {
        shared ? dwell >= sharedEdgeDwell : true
    }

    static func frame(_ target: DragSnapTarget, in visibleFrame: CGRect) -> CGRect? {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }
        let half = floor(visibleFrame.width / 2)
        switch target {
            case .none: return nil
            case .leftHalf: return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: half, height: visibleFrame.height)
            case .rightHalf: return CGRect(x: visibleFrame.minX + half, y: visibleFrame.minY, width: visibleFrame.width - half, height: visibleFrame.height)
            // the visible desktop rect, deliberately not a macOS fullscreen Space
            case .fill: return visibleFrame
        }
    }
}

/// No default: every candidate collides with something, so the user picks one knowingly or the module
/// stays off. The assessment behind each case is in the backlog's modifier table.
enum DragScreenNeighbours {
    /// An edge shared with another display is an ordinary cursor route onto that display, so it must not
    /// snap on distance alone. Adjacency needs the edges to touch and the vertical ranges to overlap:
    /// displays stacked diagonally do not share a usable edge.
    static func hasNeighbour(left: Bool, of frame: CGRect, among frames: [CGRect], tolerance: CGFloat = 2) -> Bool {
        frames.contains { other in
            guard other != frame else { return false }
            let touches = left ? abs(other.maxX - frame.minX) <= tolerance : abs(other.minX - frame.maxX) <= tolerance
            return touches && other.minY < frame.maxY && other.maxY > frame.minY
        }
    }
}

enum DragModifierPreference: String, CaseIterable {
    case disabled
    case commandShift
    case fn
    case commandControl

    /// What the settings picker offers today. `commandControl` is deliberately absent: it needs ownership
    /// of the global `NSWindowShouldDragOnGesture` value first. Appending to this list later keeps the
    /// stored indexes of the existing entries stable.
    static let selectable: [DragModifierPreference] = [.disabled, .commandShift, .fn]

    /// `Command+Control` consumes the primary mouse down, which macOS otherwise delivers as a secondary
    /// click, and it only works once the global drag-on-gesture setting is off.
    var requiresWindowDragOnGestureDisabled: Bool {
        self == .commandControl
    }

    var isEnabled: Bool {
        self != .disabled
    }

    var requiredFlags: NSEvent.ModifierFlags? {
        switch self {
            case .disabled: return nil
            case .commandShift: return [.command, .shift]
            case .fn: return [.function]
            case .commandControl: return [.command, .control]
        }
    }

    /// Exact match on the modifiers that matter: a stray Option or Shift must not arm a drag the user did
    /// not ask for.
    func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        guard let required = requiredFlags else { return false }
        let relevant: NSEvent.ModifierFlags = [.command, .shift, .control, .option, .function]
        return flags.intersection(relevant) == required
    }
}
