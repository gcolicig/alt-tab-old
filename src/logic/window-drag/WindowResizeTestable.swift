import AppKit
import CoreGraphics
import Foundation

/// Which corner of the window follows the cursor. The opposite corner stays put, so a resize never moves
/// the window as a side effect: grabbing near the bottom right and pulling grows the window there, exactly
/// as dragging that corner's grip would.
///
/// Named in Quartz terms, matching `CGEvent.location` and the AX position attribute: `top` is `minY`.
enum ResizeAnchor: Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var movesLeftEdge: Bool { self == .topLeft || self == .bottomLeft }
    var movesTopEdge: Bool { self == .topLeft || self == .topRight }
}

/// Move and resize are separate modules with separate modifiers, so a session has to know which one it is.
enum DragMode: Equatable {
    case move
    case resize
}

enum DragModeSelection {
    /// `move` wins a tie. The settings refuse to give both modules the same modifier, so a tie only happens
    /// if a preference file was edited by hand, and silently moving is safer than silently resizing.
    static func mode(_ flags: NSEvent.ModifierFlags, move: DragModifierPreference, resize: DragModifierPreference) -> DragMode? {
        if move.matches(flags) { return .move }
        if resize.matches(flags) { return .resize }
        return nil
    }

    /// Two modules listening for the same combination would both claim the same mouse down.
    static func conflict(move: DragModifierPreference, resize: DragModifierPreference) -> Bool {
        move.isEnabled && resize.isEnabled && move == resize
    }
}

enum WindowResizeGeometry {
    /// Below this a window is not usefully resizable and mostly ends up unusable. Apps enforce their own
    /// minimums too; this only keeps the proposed frame sane before AX ever sees it.
    static let minimumSize = CGSize(width: 120, height: 80)

    /// The quadrant the drag started in decides the corner. Using the start point rather than the current
    /// one keeps the anchor fixed for the whole session, so crossing the middle of the window mid-drag does
    /// not suddenly flip which edge is growing.
    static func anchor(for start: CGPoint, in frame: CGRect) -> ResizeAnchor {
        let left = start.x < frame.midX
        let top = start.y < frame.midY
        if top { return left ? .topLeft : .topRight }
        return left ? .bottomLeft : .bottomRight
    }

    static func frame(from origin: CGRect, anchor: ResizeAnchor, delta: CGSize) -> CGRect {
        var left = origin.minX
        var right = origin.maxX
        var top = origin.minY
        var bottom = origin.maxY
        if anchor.movesLeftEdge { left += delta.width } else { right += delta.width }
        if anchor.movesTopEdge { top += delta.height } else { bottom += delta.height }
        // clamping pushes back the edge the cursor is dragging, never the one that must stay put
        if right - left < minimumSize.width {
            if anchor.movesLeftEdge { left = right - minimumSize.width } else { right = left + minimumSize.width }
        }
        if bottom - top < minimumSize.height {
            if anchor.movesTopEdge { top = bottom - minimumSize.height } else { bottom = top + minimumSize.height }
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
