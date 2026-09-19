import Foundation

/// Groups the Window Layouts shortcuts into titled sections for the settings page. `restore` is folded
/// into `focus` because it would otherwise be the only row in its own section.
enum WindowLayoutSection: CaseIterable {
    case thirds
    case threeQuarters
    case focus

    var title: String {
        switch self {
        case .thirds: return NSLocalizedString("Thirds", comment: "")
        case .threeQuarters: return NSLocalizedString("Three-quarters", comment: "")
        case .focus: return NSLocalizedString("Focus and restore", comment: "")
        }
    }
}

enum WindowLayoutSections {
    static func section(_ action: WindowLayoutAction) -> WindowLayoutSection {
        switch action {
        case .leftThird, .rightThird, .leftTwoThirds, .rightTwoThirds: return .thirds
        case .leftThreeQuarters, .rightThreeQuarters: return .threeQuarters
        case .leftFocus, .centerFocus, .rightFocus, .restore: return .focus
        }
    }

    /// Every action grouped by section, sections and actions both kept in `WindowLayoutSection.allCases`
    /// / `WindowLayoutAction.allCases` order.
    static func grouped(_ actions: [WindowLayoutAction] = WindowLayoutAction.allCases) -> [(WindowLayoutSection, [WindowLayoutAction])] {
        WindowLayoutSection.allCases.map { section in
            (section, actions.filter { self.section($0) == section })
        }.filter { !$0.1.isEmpty }
    }
}
