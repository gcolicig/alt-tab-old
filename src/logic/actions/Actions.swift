import Cocoa

enum Actions {
    /// Built once: every entry reads its own mutable state through closures, so the registry itself
    /// never goes stale and must not be rebuilt on the shortcut path.
    static let registry = ActionRegistry(
        WindowLayoutAction.allCases.map(windowLayoutRegistration) +
            DisplayMoveAction.allCases.map(displayMoveRegistration) +
            SpaceAction.all.map(spaceRegistration) +
            (0..<Preferences.maxLaunchAppCount).map(launchAppRegistration) +
            (0..<Preferences.maxOpenUrlCount).map(openUrlRegistration)
    )

    @discardableResult
    static func perform(_ id: ActionIdentifier) -> Bool {
        registry.perform(id)
    }

    private static func windowLayoutRegistration(_ action: WindowLayoutAction) -> RegisteredAction {
        RegisteredAction(id: .windowLayout(action), title: { action.localizedTitle }, availability: windowLayoutAvailability) {
            WindowLayouts.perform(action)
        }
    }

    private static func displayMoveRegistration(_ action: DisplayMoveAction) -> RegisteredAction {
        RegisteredAction(id: .displayMove(action), title: { action.localizedTitle }, availability: displayMoveAvailability) {
            WindowLayouts.perform(action)
        }
    }

    private static func displayMoveAvailability() -> ActionAvailability {
        guard NSScreen.screens.count > 1 else {
            return .unavailable(NSLocalizedString("Only one display is connected.", comment: ""))
        }
        return windowLayoutAvailability()
    }

    private static func spaceRegistration(_ action: SpaceAction) -> RegisteredAction {
        RegisteredAction(id: .space(action), title: { action.localizedTitle }, availability: { InstantSpaces.availability(action) }) {
            InstantSpaces.perform(action)
        }
    }

    private static func launchAppRegistration(_ index: Int) -> RegisteredAction {
        RegisteredAction(id: .launchApp(index), title: { LaunchAppAction.localizedTitle(index) }, availability: { LaunchAppAction.availability(index) }) {
            LaunchAppAction.perform(index)
        }
    }

    private static func openUrlRegistration(_ index: Int) -> RegisteredAction {
        RegisteredAction(id: .openUrl(index), title: { OpenUrlAction.localizedTitle(index) }, availability: { OpenUrlAction.availability(index) }) {
            OpenUrlAction.perform(index)
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
