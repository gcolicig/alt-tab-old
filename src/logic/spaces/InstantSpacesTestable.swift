import Foundation

enum SpaceAction: Hashable {
    case left
    case right
    case index(Int)

    static var all: [SpaceAction] {
        [.left, .right] + (1...9).map { .index($0) }
    }

    var stableId: String {
        switch self {
        case .left: return "left"
        case .right: return "right"
        case .index(let index): return "index.\(index)"
        }
    }

    var shortcutPreferenceKey: String {
        switch self {
        case .left: return "spaceLeftShortcut"
        case .right: return "spaceRightShortcut"
        case .index(let index): return "space\(index)Shortcut"
        }
    }

    var localizedTitle: String {
        switch self {
        case .left: return NSLocalizedString("Space left", comment: "")
        case .right: return NSLocalizedString("Space right", comment: "")
        case .index(let index): return String(format: NSLocalizedString("Space %d", comment: ""), index)
        }
    }
}

enum SpaceSwitchDirection: Equatable {
    case left
    case right
}

struct SpaceSwitchPlan: Equatable {
    let direction: SpaceSwitchDirection
    let steps: Int
    let targetIndex: Int
}

struct SpacePrediction: Equatable {
    let sourceIndex: Int
    let targetIndex: Int
    let timestamp: TimeInterval
}

struct SpacePredictionPolicy {
    /// A prediction only bridges the gap until the system reports the new Space. Anything older
    /// describes a switch that already settled or silently failed, and must not seed the next plan.
    static let validity = TimeInterval(0.5)

    static func baseIndex(observedIndex: Int, prediction: SpacePrediction?, now: TimeInterval) -> Int {
        guard let prediction, now - prediction.timestamp <= validity else { return observedIndex }
        // trust the prediction while the switch is still in flight or has landed as expected;
        // any other observation means a step was dropped, so plan from what the system reports.
        guard observedIndex == prediction.sourceIndex || observedIndex == prediction.targetIndex else { return observedIndex }
        return prediction.targetIndex
    }
}

struct SpaceSwitchPlanner {
    static func stepDirection(currentIndex: Int, targetIndex: Int, spaceCount: Int) -> SpaceSwitchDirection? {
        guard spaceCount > 0, (0..<spaceCount).contains(currentIndex), (0..<spaceCount).contains(targetIndex),
              currentIndex != targetIndex else { return nil }
        return targetIndex < currentIndex ? .left : .right
    }

    static func plan(_ action: SpaceAction, currentIndex: Int, spaceCount: Int) -> SpaceSwitchPlan? {
        guard spaceCount > 0, (0..<spaceCount).contains(currentIndex) else { return nil }
        let targetIndex: Int
        switch action {
        case .left: targetIndex = currentIndex - 1
        case .right: targetIndex = currentIndex + 1
        case .index(let oneBasedIndex): targetIndex = oneBasedIndex - 1
        }
        guard (0..<spaceCount).contains(targetIndex), targetIndex != currentIndex else { return nil }
        let direction: SpaceSwitchDirection = targetIndex < currentIndex ? .left : .right
        return SpaceSwitchPlan(direction: direction, steps: abs(targetIndex - currentIndex), targetIndex: targetIndex)
    }

    static func dockOverlayIsActive(_ layers: [Int]) -> Bool {
        layers.contains(18) && layers.contains(20)
    }
}
