enum ActionIdentifier: Hashable {
    case windowLayout(WindowLayoutAction)
    case displayMove(DisplayMoveAction)
    case space(SpaceAction)
    case launchApp(Int)
    case openUrl(Int)

    var stableId: String {
        switch self {
        case .windowLayout(let action): return "windowLayout.\(action.rawValue)"
        case .displayMove(let action): return "displayMove.\(action.rawValue)"
        case .space(let action): return "space.\(action.stableId)"
        case .launchApp(let index): return "launchApp.\(index)"
        case .openUrl(let index): return "openUrl.\(index)"
        }
    }
}

enum ActionAvailability: Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

struct RegisteredAction {
    let id: ActionIdentifier
    let title: String
    let availability: () -> ActionAvailability
    let execute: () -> Void
}

final class ActionRegistry {
    private let actions: [ActionIdentifier: RegisteredAction]

    init(_ registrations: [RegisteredAction]) {
        var actions = [ActionIdentifier: RegisteredAction]()
        registrations.forEach {
            precondition(actions[$0.id] == nil, "Duplicate action identifier: \($0.id.stableId)")
            actions[$0.id] = $0
        }
        self.actions = actions
    }

    var registeredActions: [RegisteredAction] {
        actions.values.sorted { $0.id.stableId < $1.id.stableId }
    }

    func action(_ id: ActionIdentifier) -> RegisteredAction? {
        actions[id]
    }

    func availability(_ id: ActionIdentifier) -> ActionAvailability {
        actions[id]?.availability() ?? .unavailable("Unknown action")
    }

    @discardableResult
    func perform(_ id: ActionIdentifier) -> Bool {
        guard let action = actions[id], action.availability().isAvailable else { return false }
        action.execute()
        return true
    }
}
