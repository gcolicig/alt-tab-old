import Cocoa

enum WindowLayoutAction: String, CaseIterable {
    case leftThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case restore

    var shortcutPreferenceKey: String {
        "windowLayout\(rawValue.prefix(1).uppercased())\(rawValue.dropFirst())Shortcut"
    }

    var localizedTitle: String {
        switch self {
        case .leftThird: return NSLocalizedString("Left third", comment: "")
        case .rightThird: return NSLocalizedString("Right third", comment: "")
        case .leftTwoThirds: return NSLocalizedString("Left two-thirds", comment: "")
        case .rightTwoThirds: return NSLocalizedString("Right two-thirds", comment: "")
        case .restore: return NSLocalizedString("Restore", comment: "")
        }
    }
}

struct WindowLayoutGeometry {
    static func frame(_ action: WindowLayoutAction, in visibleFrame: CGRect) -> CGRect? {
        guard action != .restore, visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }
        let oneThird = floor(visibleFrame.width / 3)
        let twoThirds = floor(visibleFrame.width * 2 / 3)
        switch action {
        case .leftThird:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: oneThird, height: visibleFrame.height)
        case .rightThird:
            return CGRect(x: visibleFrame.minX + twoThirds, y: visibleFrame.minY, width: visibleFrame.maxX - visibleFrame.minX - twoThirds, height: visibleFrame.height)
        case .leftTwoThirds:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: twoThirds, height: visibleFrame.height)
        case .rightTwoThirds:
            return CGRect(x: visibleFrame.minX + oneThird, y: visibleFrame.minY, width: visibleFrame.maxX - visibleFrame.minX - oneThird, height: visibleFrame.height)
        case .restore:
            return nil
        }
    }
}
