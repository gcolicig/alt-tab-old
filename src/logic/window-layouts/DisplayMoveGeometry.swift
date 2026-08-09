import Cocoa

enum DisplayMoveAction: String, CaseIterable {
    case nextDisplay
    case previousDisplay

    var shortcutPreferenceKey: String {
        "windowMove\(rawValue.prefix(1).uppercased())\(rawValue.dropFirst())Shortcut"
    }

    var localizedTitle: String {
        switch self {
        case .nextDisplay: return NSLocalizedString("Move to next display", comment: "")
        case .previousDisplay: return NSLocalizedString("Move to previous display", comment: "")
        }
    }
}

/// Moves a window between displays while keeping how it sits on its display: a window filling the left
/// half stays a left half, and a window that is too large for the target is bounded by it.
struct DisplayMoveGeometry {
    /// Displays are ordered left to right, then top to bottom, so `next` and `previous` follow the
    /// physical arrangement instead of the order the system happens to report.
    static func orderedFrames(_ screenFrames: [CGRect]) -> [CGRect] {
        screenFrames.sorted {
            $0.origin.x != $1.origin.x ? $0.origin.x < $1.origin.x : $0.origin.y < $1.origin.y
        }
    }

    static func targetScreenIndex(_ action: DisplayMoveAction, currentIndex: Int, screenCount: Int) -> Int? {
        guard screenCount > 1, (0..<screenCount).contains(currentIndex) else { return nil }
        let step = action == .nextDisplay ? 1 : -1
        return (currentIndex + step + screenCount) % screenCount
    }

    static func frame(_ windowFrame: CGRect, from source: CGRect, to target: CGRect) -> CGRect? {
        guard source.width > 0, source.height > 0, target.width > 0, target.height > 0 else { return nil }
        let relativeX = (windowFrame.origin.x - source.origin.x) / source.width
        let relativeY = (windowFrame.origin.y - source.origin.y) / source.height
        let width = min(windowFrame.width / source.width * target.width, target.width)
        let height = min(windowFrame.height / source.height * target.height, target.height)
        let x = target.origin.x + min(max(relativeX, 0), 1) * target.width
        let y = target.origin.y + min(max(relativeY, 0), 1) * target.height
        return CGRect(x: min(x, target.maxX - width), y: min(y, target.maxY - height), width: width, height: height)
    }
}
