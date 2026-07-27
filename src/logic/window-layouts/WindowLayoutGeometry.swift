import Cocoa

enum WindowLayoutAction: String, CaseIterable {
    case leftThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case leftThreeQuarters
    case rightThreeQuarters
    case leftFocus
    case centerFocus
    case rightFocus
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
        case .leftThreeQuarters: return NSLocalizedString("Left three-quarters", comment: "")
        case .rightThreeQuarters: return NSLocalizedString("Right three-quarters", comment: "")
        case .leftFocus: return NSLocalizedString("Left focus", comment: "")
        case .centerFocus: return NSLocalizedString("Center focus", comment: "")
        case .rightFocus: return NSLocalizedString("Right focus", comment: "")
        case .restore: return NSLocalizedString("Restore", comment: "")
        }
    }
}

struct WindowLayoutGeometry {
    static let centerFocusMargin = CGFloat(12)
    static let edgeFocusMargin = CGFloat(24)
    static let centerFocusVerticalReveal = CGFloat(12)

    static func frame(_ action: WindowLayoutAction, in visibleFrame: CGRect) -> CGRect? {
        guard action != .restore, visibleFrame.width > 0, visibleFrame.height > 0 else { return nil }
        let oneThird = floor(visibleFrame.width / 3)
        let twoThirds = floor(visibleFrame.width * 2 / 3)
        let oneQuarter = floor(visibleFrame.width / 4)
        let threeQuarters = floor(visibleFrame.width * 3 / 4)
        let centerMargin = min(centerFocusMargin, visibleFrame.width / 2)
        let edgeMargin = min(edgeFocusMargin, visibleFrame.width)
        let verticalReveal = min(centerFocusVerticalReveal, visibleFrame.height / 2)
        let sideHeight = max(0, visibleFrame.height - verticalReveal * 2)
        switch action {
        case .leftThird:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: oneThird, height: visibleFrame.height)
        case .rightThird:
            return CGRect(x: visibleFrame.minX + twoThirds, y: visibleFrame.minY, width: visibleFrame.maxX - visibleFrame.minX - twoThirds, height: visibleFrame.height)
        case .leftTwoThirds:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: twoThirds, height: visibleFrame.height)
        case .rightTwoThirds:
            return CGRect(x: visibleFrame.minX + oneThird, y: visibleFrame.minY, width: visibleFrame.maxX - visibleFrame.minX - oneThird, height: visibleFrame.height)
        case .leftThreeQuarters:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: threeQuarters, height: visibleFrame.height)
        case .rightThreeQuarters:
            return CGRect(x: visibleFrame.minX + oneQuarter, y: visibleFrame.minY, width: visibleFrame.maxX - visibleFrame.minX - oneQuarter, height: visibleFrame.height)
        case .leftFocus:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY + verticalReveal, width: visibleFrame.width - edgeMargin, height: sideHeight)
        case .centerFocus:
            return CGRect(x: visibleFrame.minX + centerMargin, y: visibleFrame.minY, width: visibleFrame.width - centerMargin * 2, height: visibleFrame.height)
        case .rightFocus:
            return CGRect(x: visibleFrame.minX + edgeMargin, y: visibleFrame.minY + verticalReveal, width: visibleFrame.width - edgeMargin, height: sideHeight)
        case .restore:
            return nil
        }
    }
}
