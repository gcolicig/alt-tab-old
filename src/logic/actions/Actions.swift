import Cocoa

enum Actions {
    static let registry = ActionRegistry(
        WindowLayoutAction.allCases.map(windowLayoutRegistration) +
            SpaceAction.all.map(spaceRegistration)
    )

    @discardableResult
    static func perform(_ id: ActionIdentifier) -> Bool {
        registry.perform(id)
    }

    private static func windowLayoutRegistration(_ action: WindowLayoutAction) -> RegisteredAction {
        RegisteredAction(id: .windowLayout(action), title: action.localizedTitle, availability: windowLayoutAvailability) {
            WindowLayouts.perform(action)
        }
    }

    private static func spaceRegistration(_ action: SpaceAction) -> RegisteredAction {
        RegisteredAction(id: .space(action), title: action.localizedTitle, availability: { InstantSpaces.availability(action) }) {
            InstantSpaces.perform(action)
        }
    }

    private static func windowLayoutAvailability() -> ActionAvailability {
        guard !Preferences.inputModulesSafeMode else {
            return .unavailable(NSLocalizedString("Input extensions are in safe mode.", comment: ""))
        }
        guard !App.appIsBeingUsed else {
            return .unavailable(NSLocalizedString("Close the window switcher before arranging a window.", comment: ""))
        }
        guard AXIsProcessTrusted() else {
            return .unavailable(NSLocalizedString("Accessibility permission is required.", comment: ""))
        }
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return .unavailable(NSLocalizedString("No eligible foreground application.", comment: ""))
        }
        return .available
    }
}
